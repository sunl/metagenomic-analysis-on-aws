---
title : "构建镜像"
weight : 331
---

也可以自己构建镜像并推送到ECR中，以下是预置的4个镜像的Dockerfile，供参考：
### 1.qc
:::code{showCopyAction=true showLineNumbers=false language=bash}
FROM amazonlinux:2
WORKDIR /opt/tools/

RUN \
amazon-linux-extras install java-openjdk11 -y && \
yum install perl ant git tar wget gcc make unzip openssl-devel bzip2 bzip2-devel libffi-devel -y && \
yum clean all && \
rm -rf /var/cache/yum && \
#fastqc
git clone https://github.com/s-andrews/FastQC.git && \
cd FastQC && \
ant && \
cd bin && \
chmod +x fastqc && \
cd ../.. && \
#multiqc
wget https://www.openssl.org/source/openssl-1.1.1t.tar.gz && \
tar -xzvf openssl-1.1.1t.tar.gz && \
cd openssl-1.1.1t && \
./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib && \
make -j$(nproc) && \
make install && \
ln -s /usr/local/openssl/include/openssl /usr/include/openssl && \
ln -s /usr/local/openssl/lib/libssl.so.1.1 /usr/local/lib64/libssl.so.1.1 && \
ln -s /usr/local/openssl/lib/libcrypto.so.1.1 /usr/local/lib64/libcrypto.so.1.1 && \
ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl && \
echo "/usr/local/lib64" | tee -a /etc/ld.so.conf && \
ldconfig && \
openssl version && \
cd .. && \
rm openssl-1.1.1t.tar.gz && \
rm openssl-1.1.1t -rf && \
wget https://www.python.org/ftp/python/3.10.12/Python-3.10.12.tgz && \
tar -xzf Python-3.10.12.tgz && \ 
cd Python-3.10.12/ && \
./configure --with-ensurepip=install --enable-optimizations --with-openssl=/usr/local/openssl && \
make -j$(nproc) && \
make altinstall && \
#rm /usr/bin/python3 && \
#rm /usr/bin/pip3 && \
ln -s /usr/local/bin/python3.10 /usr/bin/python3 && \
ln -s /usr/local/bin/pip3.10 /usr/bin/pip3 && \
cd .. && \
pip3 install multiqc && \
rm Python-3.10.12.tgz && \
rm Python-3.10.12 -rf && \
#trimmomatic
wget https://github.com/usadellab/Trimmomatic/files/5854859/Trimmomatic-0.39.zip && \
unzip Trimmomatic-0.39.zip && \
rm Trimmomatic-0.39.zip -f && \ 
#parallel
wget https://ftp.gnu.org/gnu/parallel/parallel-20230622.tar.bz2 && \
tar -xvf parallel-20230622.tar.bz2 && \
cd parallel-20230622 && \
./configure && \
make && \ 
make install && \
cd .. && \
rm parallel-20230622.tar.bz2 && \
rm parallel-20230622 -rf && \
#awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" \
-o "awscliv2.zip" && \
unzip awscliv2.zip && \
./aws/install && \
rm awscliv2.zip && \
rm -rf aws && \ 
aws configure set default.s3.preferred_transfer_client crt

ENV PATH=$PATH:/opt/tools/FastQC/bin:/scripts
WORKDIR /data
:::

### 2.metawrap
:::code{showCopyAction=true showLineNumbers=false language=bash}
FROM centos:8
ADD Miniconda3-latest-Linux-x86_64.sh metaWRAP-master.zip /opt/
ENV PATH=$PATH:/opt/miniconda/bin:/opt/metaWRAP/bin:/opt/tools
WORKDIR /opt/

RUN \
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* && \
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* && \
yum install unzip which -y && \
bash Miniconda3-latest-Linux-x86_64.sh -f -b -p /opt/miniconda && \
rm Miniconda3-latest-Linux-x86_64.sh && \
conda install mamba -n base -c conda-forge -y && \
mamba create -y -n metawrap-env python=2.7
SHELL ["conda", "run", "-n", "metawrap-env", "/bin/bash", "-c"]
RUN \
conda config --add channels defaults && \
conda config --add channels conda-forge && \
conda config --add channels bioconda && \
conda config --add channels ursky && \
mamba install --only-deps -c ursky metawrap-mg -y && \
pip install checkm-genome==1.0.18 --upgrade --no-deps --ignore-installed && \
conda clean -a -y && \
unzip metaWRAP-master.zip && \
mv metaWRAP-master metaWRAP && \
rm metaWRAP-master.zip -f && \
#mkdir -p /opt/metaWRAP_db/MY_CHECKM && \
checkm data setRoot /opt/metaWRAP_db/MY_CHECKM && \
sed -i 's%KRAKEN_DB=/scratch/gu/MY_KRAKEN_DB%KRAKEN_DB=/opt/metaWRAP_db/MY_KRAKEN_DB%g' /opt/metaWRAP/bin/config-metawrap && \
sed -i 's%KRAKEN2_DB=/scratch/gu/MY_KRAKEN2_DB%KRAKEN2_DB=/opt/metaWRAP_db/MY_KRAKEN2_DB%g' /opt/metaWRAP/bin/config-metawrap && \
sed -i 's%BMTAGGER_DB=/scratch/gu/BMTAGGER_DB%BMTAGGER_DB=/opt/metaWRAP_db/BMTAGGER_DB%g' /opt/metaWRAP/bin/config-metawrap && \
sed -i 's%BLASTDB=/scratch/gu/NCBI_nt%BLASTDB=/opt/metaWRAP_db/NCBI_nt%g' /opt/metaWRAP/bin/config-metawrap && \
sed -i 's%TAXDUMP=/scratch/gu/NCBI_tax%TAXDUMP=/opt/metaWRAP_db/NCBI_tax%g' /opt/metaWRAP/bin/config-metawrap && \
echo ". /opt/miniconda/etc/profile.d/conda.sh" >> ~/.bashrc && \
echo "conda activate metawrap-env" >> ~/.bashrc && \
echo "export LC_ALL=C" >> ~/.bashrc && \
echo "export LANGUAGE=en_US.UTF-8" >> ~/.bashrc && \
#awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
-o "awscliv2.zip" && \
unzip awscliv2.zip && \
./aws/install && \
rm awscliv2.zip && \
rm -rf aws && \
aws configure set default.s3.preferred_transfer_client crt && \
#aws mountpoint-s3
curl "https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.rpm" -o "mount-s3.rpm" && \
yum install mount-s3.rpm -y && \
rm mount-s3.rpm && \
yum clean all && \
rm -rf /var/cache/yum 

WORKDIR /data
:::


### 3.annotation
:::code{showCopyAction=true showLineNumbers=false language=bash}
FROM centos:8
WORKDIR /opt/
ENV PATH=$PATH:/opt/mamba/bin:/opt/seqkit:/opt/seqtk:/opt/coverm-x86_64-unknown-linux-musl-0.6.1:/opt/salmon-latest_linux_x86_64/bin:/opt/prodigal:/opt/cd-hit-v4.8.1-2019-0228:/opt/minimap2-2.26_x64-linux:/opt/mummer/bin

RUN \
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* && \
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-* && \
yum install which wget tar git gcc-c++ make unzip bzip2 bzip2-devel xz-devel zlib-devel python38-devel -y && \
yum clean all && \
rm -rf /var/cache/yum && \
rm /usr/bin/python3 -f && \
rm /usr/bin/pip3 -f && \
ln -s /usr/bin/python3.8 /usr/bin/python3 && \
ln -s /usr/bin/pip3.8 /usr/bin/pip3 && \
#seqkit
mkdir seqkit && \
cd seqkit && \
wget https://github.com/shenwei356/seqkit/releases/download/v2.5.0/seqkit_linux_amd64.tar.gz && \
tar -xzvf seqkit_linux_amd64.tar.gz && \
chmod +x seqkit && \
rm seqkit_linux_amd64.tar.gz && \
cd .. && \
#seqtk
git clone https://github.com/lh3/seqtk.git && \
cd seqtk && \
make && \
cd .. && \
#drep
git clone https://github.com/MrOlm/drep.git && \
cd drep && \
pip3 install . && \
cd .. && \
#salmon
wget https://github.com/COMBINE-lab/salmon/releases/download/v1.10.0/salmon-1.10.0_linux_x86_64.tar.gz && \
tar -xzvf salmon-1.10.0_linux_x86_64.tar.gz && \
rm salmon-1.10.0_linux_x86_64.tar.gz -f && \
#coverm
wget https://github.com/wwood/CoverM/releases/download/v0.6.1/coverm-x86_64-unknown-linux-musl-0.6.1.tar.gz && \
tar -xzvf coverm-x86_64-unknown-linux-musl-0.6.1.tar.gz && \
rm coverm-x86_64-unknown-linux-musl-0.6.1.tar.gz -f && \
#cd-hit
wget https://github.com/weizhongli/cdhit/releases/download/V4.8.1/cd-hit-v4.8.1-2019-0228.tar.gz && \
tar -xzvf cd-hit-v4.8.1-2019-0228.tar.gz && \
rm cd-hit-v4.8.1-2019-0228.tar.gz && \
cd cd-hit-v4.8.1-2019-0228 && \
make && \
cd .. && \
#minimap2
wget https://github.com/lh3/minimap2/releases/download/v2.26/minimap2-2.26_x64-linux.tar.bz2 && \
tar -xvf minimap2-2.26_x64-linux.tar.bz2 && \
rm minimap2-2.26_x64-linux.tar.bz2 && \
#checkm
pip3 install numpy matplotlib pysam checkm-genome && \
checkm data setRoot /opt/MY_CHECKM && \
#mummer
wget https://github.com/mummer4/mummer/releases/download/v4.0.0rc1/mummer-4.0.0rc1.tar.gz && \
tar -xvf mummer-4.0.0rc1.tar.gz && \
cd mummer-4.0.0rc1 && \
./configure --prefix=/opt/mummer && \
make && \
make install && \
cd .. && \
rm mummer-4.0.0rc1.tar.gz && \
rm mummer-4.0.0rc1 -rf && \
#awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
unzip awscliv2.zip && \
./aws/install && \
rm awscliv2.zip && \
rm -rf aws && \ 
aws configure set default.s3.preferred_transfer_client crt && \
#aws mountpoint-s3
curl "https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.rpm" -o "mount-s3.rpm" && \
yum install mount-s3.rpm -y && \
rm mount-s3.rpm && \
#mamba
wget -O Mambaforge.sh https://github.com/conda-forge/miniforge/releases/latest/download/Mambaforge-Linux-x86_64.sh && \
bash Mambaforge.sh -f -b -p /opt/mamba && \
rm Mambaforge.sh && \
#metaphlan
mamba install -c bioconda metaphlan && \
#prodigal
mkdir prodigal && \
cd prodigal && \
wget -O prodigal https://github.com/hyattpd/Prodigal/releases/download/v2.6.3/prodigal.linux && \
chmod +x prodigal && \
cd .. && \
#parallel
wget https://ftp.gnu.org/gnu/parallel/parallel-20230622.tar.bz2 && \
tar -xvf parallel-20230622.tar.bz2 && \
cd parallel-20230622 && \
./configure && \
make && \ 
make install && \
cd .. && \
rm parallel-20230622.tar.bz2 && \
rm parallel-20230622 -rf && \
#gtdbtk
mamba create -n gtdbtk-2.3.2 -c conda-forge -c bioconda gtdbtk=2.3.2 -y && \
conda env config vars set GTDBTK_DATA_PATH="/opt/db"
SHELL ["conda", "run", "-n", "gtdbtk-2.3.2", "/bin/bash", "-c"]
RUN \
echo ". /opt/mamba/etc/profile.d/conda.sh" >> ~/.bashrc && \
echo "conda activate gtdbtk-2.3.2" >> ~/.bashrc

WORKDIR /data
:::

4.diamond
:::code{showCopyAction=true showLineNumbers=false language=bash}
FROM amazonlinux:2
ADD nifH_family.dmnd nifH_family.dmnd.seed_idx nifH_family.faa diamond-linux64.tar.gz sratoolkit.3.0.5-centos_linux64.tar.gz \
seqkit_linux_amd64.tar.gz fastp /opt/

WORKDIR /opt
RUN \
yum install unzip wget less -y && \
yum clean all && \
chmod +x fastp && \
wget https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip && \
unzip awscli-exe-linux-x86_64.zip && \
./aws/install && \
rm awscli-exe-linux-x86_64.zip -f && \
rm aws -rf && \
aws configure set default.s3.preferred_transfer_client crt 

WORKDIR /data

ENV PATH=$PATH:/opt/:/opt/sratoolkit.3.0.5-centos_linux64/bin/
:::