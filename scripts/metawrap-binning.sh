echo 'step2 sample: '$1', threads: '$2, 'memory: '$3, 'type: '$4, 'bucket: '$5, 'dbtable: '$6
. /opt/miniconda/etc/profile.d/conda.sh
conda activate metawrap-env

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
goofys --region cn-northwest-1 $bucket $s3_mount_point
base_dir=$s3_mount_point
ls -lh $base_dir
qc_results=$base_dir/results/qc

mkdir -p /opt/metaWRAP_db/MY_CHECKM
cp $base_dir/ref_data/checkm_data/* /opt/metaWRAP_db/MY_CHECKM/ -rf

aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=3 WHERE sample='$sample'"
time1=`date +%s`

case "$type" in
    1)
        sample_prefix=${qc_results}/$sample/cleandata/$sample
        samples="${sample_prefix}.*.fastq"
        assembly_dir=$base_dir/results/sig_assembly
        binning_dir=sig_binning
        refine_dir=sig_refinement
        ;;
    3)
        sample1_prefix=${qc_results}/${sample}.S/cleandata/$sample
        sample2_prefix=${qc_results}/${sample}.Z/cleandata/$sample
        sample3_prefix=${qc_results}/${sample}.X/cleandata/$sample
        samples="${sample1_prefix}.*.fastq ${sample2_prefix}.*.fastq ${sample3_prefix}.*.fastq"
        assembly_dir=$base_dir/results/mix3_assembly
        binning_dir=mix3_binning
        refine_dir=mix3_refinement
        ;;
    # 9)
    #     sample1_prefix=${qc_results}/${sample}.G.S/cleandata/$sample
    #     sample2_prefix=${qc_results}/${sample}.G.Z/cleandata/$sample
    #     sample3_prefix=${qc_results}/${sample}.G.X/cleandata/$sample
    #     sample4_prefix=${qc_results}/${sample}.Z.S/cleandata/$sample
    #     sample5_prefix=${qc_results}/${sample}.Z.Z/cleandata/$sample
    #     sample6_prefix=${qc_results}/${sample}.Z.X/cleandata/$sample
    #     sample7_prefix=${qc_results}/${sample}.D.S/cleandata/$sample
    #     sample8_prefix=${qc_results}/${sample}.D.Z/cleandata/$sample
    #     sample9_prefix=${qc_results}/${sample}.D.X/cleandata/$sample
    #     samples="${sample1_prefix}.*.fastq ${sample2_prefix}.*.fastq ${sample3_prefix}.*.fastq ${sample4_prefix}.*.fastq ${sample5_prefix}.*.fastq ${sample6_prefix}.*.fastq ${sample7_prefix}.*.fastq ${sample8_prefix}.*.fastq ${sample9_prefix}.*.fastq"
    #     assembly_dir=$base_dir/results/mix9_assembly
    #     binning_dir=mix9_binning
    #     refine_dir=mix9_refinement
    #     ;;
    *)
        echo "type incorrect"
        exit 1
        ;;
esac
echo ${assembly_dir}
ls -lh $assembly_dir

echo "metawrap binning..."
mkdir -p ${binning_dir}
metawrap binning --metabat2 --maxbin2 --concoct -t $threads -m $memory -a ${assembly_dir}/$sample/final_assembly.fasta -o ${binning_dir}/$sample $samples
aws s3 sync ${binning_dir}/$sample/ s3://$bucket/results/${binning_dir}/$sample/ --storage-class ${storage_class}
time2=`date +%s`
interval=`expr $time2 - $time1`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=4, binning_time=$interval WHERE sample='$sample'"

echo "metawrap refinement..."
mkdir -p ${refine_dir}
metawrap bin_refinement -t $threads -m $memory -o ${refine_dir}/$sample -A ${binning_dir}/$sample/concoct_bins/ -B ${binning_dir}/$sample/maxbin2_bins/ -C ${binning_dir}/$sample/metabat2_bins/ -c 50 -x 10
aws s3 sync ${refine_dir}/$sample/ s3://$bucket/results/${refine_dir}/$sample/ --storage-class ${storage_class}
time3=`date +%s`
interval=`expr $time3 - $time2`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=5, refinement_time=$interval WHERE sample='$sample'"

echo "delete local files"
rm ${binning_dir} -rf
rm ${refine_dir} -rf

echo 'done'