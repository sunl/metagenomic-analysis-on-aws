#qc.sh
echo 'step2 sample: '$1', threads: '$2, 'bucket: '$3, 'dbtable: '$4
sample=$1
threads=$2
bucket=$3
dbtable=$4

src_path=s3://$bucket/sources
results_path=s3://$bucket/results/qc
storage_class=INTELLIGENT_TIERING

aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=1, threads=$threads WHERE sample='$sample'"
time1=`date +%s`
#unzip
mkdir -p rawdata
aws s3 sync ${src_path}/${sample}/ rawdata/
echo 'unzip...'
gunzip rawdata/*.gz
mv rawdata/${sample}.R1.fq rawdata/${sample}.R_1.fastq
mv rawdata/${sample}.R2.fq rawdata/${sample}.R_2.fastq
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=2 WHERE sample='$sample'"

echo 'quality control...'
mkdir -p fastqc_before_trimmomatic
mkdir -p multiqc_before_trimmomatic
#raw data quality check
fastqc rawdata/*.fastq -t $threads -o fastqc_before_trimmomatic/
multiqc -d fastqc_before_trimmomatic/ -o multiqc_before_trimmomatic/
echo 'upload raw data quality check results'
aws s3 sync fastqc_before_trimmomatic ${results_path}/${sample}/fastqc_before_trimmomatic/ --storage-class ${storage_class} 
aws s3 sync multiqc_before_trimmomatic ${results_path}/${sample}/multiqc_before_trimmomatic/ --storage-class ${storage_class}
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=3 WHERE sample='$sample'"

#trimmomatic
mkdir -p cleandata
java -jar /opt/tools/Trimmomatic-0.39/trimmomatic-0.39.jar PE -threads $threads -phred33 \
rawdata/${sample}.R_1.fastq rawdata/${sample}.R_2.fastq \
cleandata/${sample}.paired.R_1.fastq cleandata/${sample}.unpaired.R_1.fastq \
cleandata/${sample}.paired.R_2.fastq cleandata/${sample}.unpaired.R_2.fastq \
ILLUMINACLIP:/opt/tools/Trimmomatic-0.39/adapters/TruSeq3-PE.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:5:20 MINLEN:50
rm cleandata/*.unpaired.*
echo 'upload trimmomatic results'
aws s3 sync cleandata ${results_path}/${sample}/cleandata/ --storage-class ${storage_class}
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=4 WHERE sample='$sample'"

#pure data quality check
mkdir -p fastqc_after_trimmomatic
mkdir -p multiqc_after_trimmomatic
fastqc cleandata/*.fastq -t $threads -o fastqc_after_trimmomatic/
multiqc -d fastqc_after_trimmomatic/ -o multiqc_after_trimmomatic/
echo 'upload pure data quality check results'
aws s3 sync fastqc_after_trimmomatic ${results_path}/${sample}/fastqc_after_trimmomatic/ --storage-class ${storage_class}
aws s3 sync multiqc_after_trimmomatic ${results_path}/${sample}/multiqc_after_trimmomatic/ --storage-class ${storage_class}
time2=`date +%s`
interval=`expr $time2 - $time1`
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=5, qc_time=$interval WHERE sample='$sample'"

echo 'delete local results'
rm rawdata -rf
rm fastqc_before_trimmomatic -rf
rm multiqc_before_trimmomatic -rf
rm cleandata -rf
rm fastqc_after_trimmomatic -rf
rm multiqc_after_trimmomatic -rf
echo 'done'