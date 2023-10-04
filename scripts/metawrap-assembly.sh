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
mount-s3 $bucket $s3_mount_point --region cn-northwest-1
base_dir=$s3_mount_point
qc_results=$base_dir/results/qc
ls -lh $qc_results

aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=1 WHERE sample='$sample'"
time1=`date +%s`
case "$type" in
    1)
        echo "Single sample assembly"
        #sample=mud01.2020.11.S
        sample_prefix=${qc_results}/$sample/cleandata/$sample.paired
        sample_r1=${sample_prefix}.R_1.fastq
        sample_r2=${sample_prefix}.R_2.fastq
        assembly_dir=sig_assembly
        ;;
    3)
        echo "Mixed assembly of 3 samples"
        #sample=mud01.2020.11 or sample=sand01.2020.11.D
        sample1_prefix=${qc_results}/${sample}.S/cleandata/$sample.S.paired
        sample2_prefix=${qc_results}/${sample}.Z/cleandata/$sample.Z.paired
        sample3_prefix=${qc_results}/${sample}.X/cleandata/$sample.X.paired
        sample_r1="${sample1_prefix}.R_1.fastq,${sample2_prefix}.R_1.fastq,${sample3_prefix}.R_1.fastq"
        sample_r2="${sample1_prefix}.R_2.fastq,${sample2_prefix}.R_2.fastq,${sample3_prefix}.R_2.fastq"
        assembly_dir=mix3_assembly
        ;;
    # 9)
    #     echo "Mixed assembly of 9 samples"
    #     #sample=sand01.2020.11
    #     sample1_prefix=${qc_results}/${sample}.G.S/cleandata/$sample.G.S.paired
    #     sample2_prefix=${qc_results}/${sample}.G.Z/cleandata/$sample.G.Z.paired
    #     sample3_prefix=${qc_results}/${sample}.G.X/cleandata/$sample.G.X.paired
    #     sample4_prefix=${qc_results}/${sample}.Z.S/cleandata/$sample.Z.S.paired
    #     sample5_prefix=${qc_results}/${sample}.Z.Z/cleandata/$sample.Z.Z.paired
    #     sample6_prefix=${qc_results}/${sample}.Z.X/cleandata/$sample.Z.X.paired
    #     sample7_prefix=${qc_results}/${sample}.D.S/cleandata/$sample.D.S.paired
    #     sample8_prefix=${qc_results}/${sample}.D.Z/cleandata/$sample.D.Z.paired
    #     sample9_prefix=${qc_results}/${sample}.D.X/cleandata/$sample.D.X.paired
    #     sample_r1="${sample1_prefix}.R_1.fastq,${sample2_prefix}.R_1.fastq,${sample3_prefix}.R_1.fastq,${sample4_prefix}.R_1.fastq,${sample5_prefix}.R_1.fastq,${sample6_prefix}.R_1.fastq,${sample7_prefix}.R_1.fastq,${sample8_prefix}.R_1.fastq,${sample9_prefix}.R_1.fastq"
    #     sample_r2="${sample1_prefix}.R_2.fastq,${sample2_prefix}.R_2.fastq,${sample3_prefix}.R_2.fastq,${sample4_prefix}.R_2.fastq,${sample5_prefix}.R_2.fastq,${sample6_prefix}.R_2.fastq,${sample7_prefix}.R_2.fastq,${sample8_prefix}.R_2.fastq,${sample9_prefix}.R_2.fastq"
    #     assembly_dir=mix9_assembly
    #     ;;
    *)
        echo "type incorrect"
        exit 1
        ;;
esac

echo 'metawrap assembly '
mkdir -p ${assembly_dir}
metawrap assembly -t $threads -m $memory --megahit -o ${assembly_dir}/$sample -1 ${sample_r1} -2 ${sample_r2}

echo ${assembly_dir}
aws s3 sync ${assembly_dir}/$sample/ s3://$bucket/results/${assembly_dir}/$sample/ --storage-class ${storage_class}

time2=`date +%s`
interval=`expr $time2 - $time1`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=2, assembly_time=$interval WHERE sample='$sample'"

echo "delete local files"
rm ${assembly_dir} -rf

echo "submit metawrap binning job"
script=/scripts/metawrap-binning.sh
threads=32
memory=58
jobqueue='q-metawrap-binning'
jobdef='jd-metawrap-binning:5'
jobname=$dbtable-${sample//./_}-$threads
aws batch submit-job --job-name $jobname --job-queue $jobqueue --job-definition $jobdef --parameters script=$script,sample=$sample,threads=$threads,memory=$memory,type=$type,bucket=$bucket,dbtable=$dbtable

echo 'done'