---
title : "大规模任务"
weight : 51
---

本节通过批量运行质控任务来演示如何大规模运行计算任务

1.上传任务源数据到S3桶中，可以复制这些示例数据：
::alert[123456789012换成你自己的账户ID]

:::code{showCopyAction=true showLineNumbers=false language=bash}
aws s3 sync s3://hyes/demo_samples/ s3://metagenomic-123456789012-cn-northwest-1/sources/ --request-payer requester
:::

如下图：

![](/static/notebook-sources.png)

完成后S3桶中包含参考数据库和输入数据：

![](/static/notebook-s3.png)

2.打开notebook/job-submit-qc.ipynb，运行python提交任务.

sample-info.xlsx文件每一行都包含需要处理的一个样本信息，如果有更多字段需求可自行添加，具体逻辑参考如下代码：
:::code{showCopyAction=true showLineNumbers=false language=bash}
import openpyxl
import boto3
import re

##################################################################
#excel中保存输入文件信息
wb = openpyxl.load_workbook('sample-info.xlsx')
sheet = wb['metagenomic']
#改成你自己的账户ID
account='691348495649'

##################################################################
#任务脚本
script = '/scripts/qc.sh'
#任务信息保存在DynamoDB表中
dbtable = 'metagenomic_qc'
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(dbtable)
#输入文件存储在该S3桶中
bucket = 'metagenomic-' + account + '-cn-northwest-1'

batch = boto3.client('batch')
#Batch任务定义，注意修订号
jobdef='jd-qc-test:1'
#Batch任务队列
jobqueue='q-qc-test'

for row in sheet.iter_rows(min_row=2):
    sample = row[0].value
    threads=16
    memory='31500'
    
    # init ddb table
    table.put_item(
       Item={
            'sample': sample,
            'threads': threads,
            'qc_time': 0,
            'status': 0
        }
    )
    
    # submit jobs
    jobname = sample + '-' + str(threads)
    print('jobname: ', jobname, 'queue: ', jobqueue)
    params = {
        'script':script,
        'sample':sample,
        'threads':str(threads),
        'bucket':bucket,
        'dbtable':dbtable
    }
    resourceRequirements = [
        {
            'value':str(threads),
            'type':'VCPU'
        },
        {
            'value':memory,
            'type':'MEMORY'
        },
    ]
    response = batch.submit_job(
        jobName=jobname,
        jobQueue=jobqueue,
        jobDefinition=jobdef,
        parameters=params,
        containerOverrides={
            'resourceRequirements':resourceRequirements
        }
    )
    print(response)
:::

针对每一个样本会提交一个任务，如下图：

![](/static/job-submit-large.png)

3.查看Batch中的任务：

![](/static/job-batch-qc-large-scale.png)

查看DynamoDB表中的任务执行状态信息：

![](/static/job-ddb-qc.png)

查看S3桶中的结果文件：

![](/static/job-s3-qc.png)