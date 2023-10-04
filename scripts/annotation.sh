echo 'sample: '$1', threads: '$2, 'memory: '$3, 'type: '$4, 'bucket: '$5, 'dbtable: '$6
. /opt/mamba/etc/profile.d/conda.sh
conda activate gtdbtk-2.3.2

sample=$1
threads=$2
memory=$3
type=$4
bucket=$5
dbtable=$6

storage_class=INTELLIGENT_TIERING
s3_mount_point=/s3

echo 'mount s3 bucket'
mkdir -p $s3_mount_point
mount-s3 $bucket $s3_mount_point --region cn-northwest-1 
base_dir=$s3_mount_point
ls -lh $base_dir
qc_results=$base_dir/results/qc

aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=1 WHERE sample='$sample'"
time1=`date +%s`

case "$type" in
    1)
        sample_prefix=${qc_results}/$sample/cleandata/$sample.paired
        echo $sample_prefix >> metadata.txt
        echo $sample >> samples.txt
        samples="${sample_prefix}.*.fastq"
        assembly_dir=$base_dir/results/sig_assembly
        binning_dir=$base_dir/results/sig_binning
        refine_dir=$base_dir/results/sig_refinement
        ;;
    3)
        sample1_prefix=${qc_results}/${sample}.S/cleandata/$sample.S.paired
        sample2_prefix=${qc_results}/${sample}.Z/cleandata/$sample.Z.paired
        sample3_prefix=${qc_results}/${sample}.X/cleandata/$sample.X.paired
        for i in {1..3}; do
            line=sample${i}_prefix
            echo ${!line} >> metadata.txt 
        done
        echo $sample.S >> samples.txt
        echo $sample.Z >> samples.txt
        echo $sample.X >> samples.txt
        samples="${sample1_prefix}.*.fastq ${sample2_prefix}.*.fastq ${sample3_prefix}.*.fastq"
        assembly_dir=$base_dir/results/mix3_assembly
        binning_dir=$base_dir/results/mix3_binning
        refine_dir=$base_dir/results/mix3_refinement
        ;;
    9)
        sample1_prefix=${qc_results}/${sample}.G.S/cleandata/$sample.G.S.paired
        sample2_prefix=${qc_results}/${sample}.G.Z/cleandata/$sample.G.Z.paired
        sample3_prefix=${qc_results}/${sample}.G.X/cleandata/$sample.G.X.paired
        sample4_prefix=${qc_results}/${sample}.Z.S/cleandata/$sample.Z.S.paired
        sample5_prefix=${qc_results}/${sample}.Z.Z/cleandata/$sample.Z.Z.paired
        sample6_prefix=${qc_results}/${sample}.Z.X/cleandata/$sample.Z.X.paired
        sample7_prefix=${qc_results}/${sample}.D.S/cleandata/$sample.D.S.paired
        sample8_prefix=${qc_results}/${sample}.D.Z/cleandata/$sample.D.Z.paired
        sample9_prefix=${qc_results}/${sample}.D.X/cleandata/$sample.D.X.paired
        for i in {1..9}; do
            line=sample${i}_prefix
            echo ${!line} >> metadata.txt 
        done
        echo $sample.G.S >> samples.txt
        echo $sample.G.Z >> samples.txt
        echo $sample.G.X >> samples.txt
        echo $sample.Z.S >> samples.txt
        echo $sample.Z.Z >> samples.txt
        echo $sample.Z.X >> samples.txt
        echo $sample.D.S >> samples.txt
        echo $sample.D.Z >> samples.txt
        echo $sample.D.X >> samples.txt
        samples="${sample1_prefix}.*.fastq ${sample2_prefix}.*.fastq ${sample3_prefix}.*.fastq ${sample4_prefix}.*.fastq ${sample5_prefix}.*.fastq ${sample6_prefix}.*.fastq ${sample7_prefix}.*.fastq ${sample8_prefix}.*.fastq ${sample9_prefix}.*.fastq"
        assembly_dir=$base_dir/results/mix9_assembly
        binning_dir=$base_dir/results/mix9_binning
        refine_dir=$base_dir/results/mix9_refinement
        ;;
    *)
        echo "type incorrect"
        exit 1
        ;;
esac

mkdir -p /opt/MY_CHECKM
cp $base_dir/ref_data/checkm_data/* /opt/MY_CHECKM/ -rf

#链接bin到一个文件夹中
mkdir -p mix_before_drep
cp $refine_dir/$sample/metawrap_50_10_bins/bin.* mix_before_drep/
rename "bin" "mix_mud01" mix_before_drep/bin.*
#去冗余
mkdir -p mix_after_drep
dRep dereplicate mix_after_drep/ -g mix_before_drep/*.fa -sa 0.95 -nc 0.30 -comp 50 -p $threads -d #设成96个线程会卡住
time2=`date +%s`
interval=`expr $time2 - $time1`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=2, drep_time=$interval WHERE sample='$sample'"

#coverM计算MAG在每个样品中的丰度(6h)
mkdir -p coverm
coverm genome --coupled $samples --genome-fasta-files mix_after_drep/dereplicated_genomes/*.fa -o coverm/mix_coverm_MAGabundance.tsv
time3=`date +%s`
interval=`expr $time3 - $time2`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=3, coverm_time=$interval WHERE sample='$sample'"

#gtdbtk（GTDB-Tk >=2.3.0版本）注释MAG物种(1.5h) 建议用64vcpu Setting pplacer CPUs to 64, as pplacer is known to hang if >64 are used
mkdir -p mix_gtdbtk_annotation
export GTDBTK_DATA_PATH=$base_dir/ref_data/gtdbtk/release214/
if [ $threads -gt 64 ]; then
    cpus=64
else
    cpus=$threads
fi
gtdbtk classify_wf --genome_dir mix_after_drep/dereplicated_genomes/ --out_dir mix_gtdbtk_annotation --extension fa --skip_ani_screen --prefix tax --cpus $cpus
time4=`date +%s`
interval=`expr $time4 - $time3`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=4, gtdbtk_time=$interval WHERE sample='$sample'"

#metaphlan3物种注释（无时间预估，预计数小时）,如果是9样本，--nporc 16建议根据机器配置调整为合适的值
mkdir -p metaphlan
parallel -j $type --xapply "metaphlan {1}.R_1.fastq,{1}.R_2.fastq --bowtie2out {2}.bowtie2.bz2 --nproc 16 --input_type fastq -o metaphlan/metaphlan_{2}.txt --bowtie2db /s3/ref_data/metaphlan_databases" ::: `tail metadata.txt` ::: `tail samples.txt`
merge_metaphlan_tables.py metaphlan/metaphlan_*.txt > metaphlan/merged_abundance_table.txt
time5=`date +%s`
interval=`expr $time5 - $time4`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=5, metaphlan_time=$interval WHERE sample='$sample'"

#prodigal基因预测（无时间预估，预计数小时）
mkdir -p prodigal
prodigal -i ${assembly_dir}/${sample}/megahit/final.contigs.fa -d prodigal/${sample}.fa -o prodigal/${sample}.gff -p meta -f gff
time6=`date +%s`
interval=`expr $time6 - $time5`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=6, prodigal_time=$interval WHERE sample='$sample'"

#cd-hit构建非冗余基因集（1.5h）
mkdir -p cd-hit
cat prodigal/${sample}.fa >> cd-hit/all_gene.fa
cd-hit-est -i cd-hit/all_gene.fa -o cd-hit/nucleotide.fa -aS 0.9 -c 0.95 -G 0 -M $memory -T $threads -g 1
seqkit translate --trim cd-hit/nucleotide.fa > cd-hit/protein.fa
time7=`date +%s`
interval=`expr $time7 - $time6`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=7, cdhit_time=$interval WHERE sample='$sample'"

#将基因序列ID去重复
mkdir -p salmon
cp cd-hit/nucleotide.fa salmon/nucleotide.fa.bak
seqkit rename salmon/nucleotide.fa.bak -o salmon/nucleotide_renamed.fa
time8=`date +%s`
interval=`expr $time8 - $time7`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=8, seqkit_time=$interval WHERE sample='$sample'"

#建索引
salmon index -t salmon/nucleotide_renamed.fa -p $threads -i salmon/index
#定量（1h）（注意区分下文的1和l）
parallel -j $type --xapply "salmon quant -i salmon/index -l A -p 16 --meta -1 {1}.R_1.fastq -2 {1}.R_2.fastq -o salmon/{2}.quant" ::: `tail -n+2 metadata.txt` ::: `tail samples.txt`

#合并
mkdir -p salmon/salmon_result
salmon quantmerge --quants salmon/*.quant -o salmon/salmon_result/gene.TPM
salmon quantmerge --quants salmon/*.quant --column NumReads -o salmon/salmon_result/gene.count
sed -i '1 s/.quant//g' salmon/salmon_result/gene.*

time9=`date +%s`
interval=`expr $time9 - $time8`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=9, salmon_time=$interval WHERE sample='$sample'"

echo 'upload to s3...'
aws s3 sync . s3://$bucket/results/annotation/$sample/ --storage-class ${storage_class}
echo 'delete local files...'
rm * -rf

echo 'done'