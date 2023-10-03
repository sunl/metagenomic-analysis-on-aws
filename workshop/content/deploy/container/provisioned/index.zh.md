---
title : "预置镜像"
weight : 330
---

1.本方案预先构建了4个容器镜像，简便起见，放在同一个镜像仓库中，通过标签来区分：

![](/static/container-images.png)

分别包含以下软件，可复制URI拉取：

|镜像标签|包含的软件|URI|
|:-|:-|:-|
|qc|astqc, multiqc, trimmomatic, parallel, awscli|:code[public.ecr.aws/n5d9q4w7/metagenomic:qc]{showCopyAction=true}|
|metawrap|metawrap, mount-s3, awscli|:code[public.ecr.aws/n5d9q4w7/metagenomic:metawrap]{showCopyAction=true}|
|annotation|seqkit, seqtk, drep, coverm, cd-hit, minimap2, checkm, mummer, metaphlan, prodigal, gtdbtk, parallel, mamba, mount-s3, awscli|:code[public.ecr.aws/n5d9q4w7/metagenomic:annotation]{showCopyAction=true}|
|diamond|diamond, sratoolkit, seqkit, fastp, awscli|:code[public.ecr.aws/n5d9q4w7/metagenomic:diamond]{showCopyAction=true}|

2.打开:link[SageMaker Notebook控制台]{href="https://cn-northwest-1.console.amazonaws.cn/sagemaker/home?region=cn-northwest-1#/notebook-instances"}, 打开笔记本实例的JupyterLab:
![](/static/notebook-console.png)

进入metagenomic-analysis-on-aws/notebook目录，可通过container-images.ipynb笔记本中的脚本把预置镜像推送到你自己账号的ECR中：

![](/static/notebook-container.png)