time0=`date +%s`
srr=$1
threads=$2
dbtable=$3
bucket=$4

storage_class=INTELLIGENT_TIERING

###################### Step1 ######################
echo 'job start, srr: '$srr', threads: '$threads', dbtable: '$dbtable', bucket: '$bucket

aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=0 WHERE srr='$srr' and threads=$threads"

rm $srr -rf
## sra-tools下载走公网，较慢，不用这种方式
# prefetch $srr --max-size u

# 获取文件的s3 uri, 使用awscli 通过内网下载的方式加速 
mkdir -p $srr

retry=0
max_retries=3
while [ $retry -lt $max_retries ]; do
  # 获取srr信息
  srrinfo=`vdb-dump $srr --info`
  echo 'srrinfo: '$srrinfo
  url=`echo $srrinfo | grep -oP 'https\S*'`
  echo 'url: '$url
  if [ -z "$url" ]; then
      echo "url is empty, retrying $retry/$max_retries" 
      retry=`expr $retry + 1`
      sleep 5
      continue
  fi
  
  break
done

if [ $retry -eq $max_retries ]; then
    echo "failed to get $srr URL after $max_retries retries, set status to -1"
    aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=-1 WHERE srr='$srr' and threads=$threads"
    exit 1
else
    # 替换 https 为 s3
    s3uri="${url/https/s3}"
    # 去除 .s3.amazonaws.com
    s3uri="${s3uri/.s3.amazonaws.com}"
    echo "s3uri: $s3uri"
    # 使用awscli 通过内网下载
    if aws s3 cp $s3uri ${srr}/${srr}.sra --no-sign-request; then
        echo "downloaded with awscli" 
    else
        echo "object does not exist, use prefetch to download"
        prefetch $srr --max-size u
    fi
fi

time1=`date +%s`
interval=`expr $time1 - $time0`
echo 'download done, set status to 1'
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=1, s3uri='$s3uri', dl_time=$interval WHERE srr='$srr' and threads=$threads"

# Extract fastq-file(s) from SRA - accessions
echo 'fasterq-dump...'
fasterq-dump $srr --outdir $srr

cd $srr
ls -lh
paired=0
fq_1=${srr}.fastq
fq_2=''
# 判断是否双端
for file in *.fastq; do 
    if [[ $file == *_1.fastq ]]; then
        paired=1
        fq_1=${srr}_1.fastq
        fq_2=${srr}_2.fastq
        break
    fi
done
echo 'paired: '$paired', fq_1: '$fq_1' fq_2: '$fq_2 

time2=`date +%s`
interval=`expr $time2 - $time1`
echo 'fasterq-dump done, set status to 2'
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=2, extract_time=$interval, paired=$paired WHERE srr='$srr' and threads=$threads"

###################### Step2 #####################
outfile=${srr}_matches.tsv
seqkit_result=s3://${bucket}/results/$srr/
if [[ $paired == 1 ]]; 
then
    echo 'run paired-end'
    # # 双端序列质控
    # r1=${srr}_paired.R1.fq
    # r2=${srr}_paired.R2.fq
    # echo 'fastp...'
    # fastp -i $fq_1 -I $fq_2 -o $r1 -O $r2 --thread $threads
    # ls -lh

    # 删除fastq以节省硬盘空间
    # echo 'delete '$fq_1' and '$fq_2' ...'
    # rm $fq_1 $fq_2 -f
    # ls -lh
    
    # 双端扫描获得id
    echo 'diamond...'
    outfile1=${srr}_matches_R1.tsv
    diamond blastx -d /opt/nifH_family.dmnd -q $fq_1 -o $outfile1 -p $threads --masking 0 --mid-sensitive -s1 -c1 -k1 -b1 --target-indexed -f 6 qseqid qstart qend qlen qstrand sseqid sstart send slen pident evalue cigar qseq_translated full_qseq full_qseq_mate 
    outfile2=${srr}_matches_R2.tsv
    diamond blastx -d /opt/nifH_family.dmnd -q $fq_2 -o $outfile2 -p $threads --masking 0 --mid-sensitive -s1 -c1 -k1 -b1 --target-indexed -f 6 qseqid qstart qend qlen qstrand sseqid sstart send slen pident evalue cigar qseq_translated full_qseq full_qseq_mate
    ls -lh

    # 序列id取并集
    cat $outfile1 $outfile2 | cut -f1 | sort | uniq > $outfile
    ls -lh

    # 根据id提取序列
    echo 'seqkit...'
    seqkit grep -f $outfile $fq_1 > ${srr}_matches.R1.fq
    seqkit grep -f $outfile $fq_2 > ${srr}_matches.R2.fq
    ls -lh

    # 上传S3
    echo 'upload...'
    aws s3 cp ${srr}_matches.R1.fq $seqkit_result --storage-class ${storage_class}
    aws s3 cp ${srr}_matches.R2.fq $seqkit_result --storage-class ${storage_class}
else
    echo 'run single-end'
    # 单端序列质控
    # r=${srr}.qc.fq
    # echo 'fastp...'
    # fastp -i $fq_1 -o $r --thread $threads
    # ls -lh

    # # 删除fastq以节省硬盘空间
    # echo 'delete '$fq_1' ...'
    # rm $fq_1 -f
    # ls -lh

    # 单端扫描获得id
    echo 'diamond...'
    diamond blastx -d /opt/nifH_family.dmnd -q $fq_1 -o $outfile -p $threads --masking 0 --mid-sensitive -s1 -c1 -k1 -b1 --target-indexed -f 6 qseqid qstart qend qlen qstrand sseqid sstart send slen pident evalue cigar qseq_translated full_qseq full_qseq_mate
    ls -lh

    # 根据id提取序列
    echo 'seqkit...'
    seqkit grep -f $outfile $fq_1 > ${srr}_qc.matches.fq
    ls -lh

    # 上传S3
    echo 'upload...'
    aws s3 cp ${srr}_qc.matches.fq $seqkit_result --storage-class ${storage_class}
fi

time3=`date +%s`
interval=`expr $time3 - $time2`
total=`expr $time3 - $time0`
echo 'fastp/diamond/seqkit/copy to s3 done, set status to 3'
aws dynamodb execute-statement --statement "UPDATE $dbtable SET status=3, process_time=$interval, total_time=$total, seqkit_result='$seqkit_result' WHERE srr='$srr' and threads=$threads"

###################### Step3 ######################
ls -lh
du -sh .
df -h
echo 'delete local files'
cd ..
rm $srr -rf
echo 'rm $srr -rf done'

echo 'done'