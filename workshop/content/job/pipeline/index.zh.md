---
title : "自动化流程"
weight : 52
---

本节演示如何运行自动化分析流程

1.打开notebook/job-submit-stepfunctions.ipynb，运行python提交任务.
::alert[123456789012换成你自己的账户ID]
:::code{showCopyAction=true showLineNumbers=false language=bash}
import openpyxl
import boto3
import re
import json
import time

sfn = boto3.client('stepfunctions')
dynamodb = boto3.resource('dynamodb')

# 改成你自己的账户ID
account='123456789012'
region='cn-northwest-1'
bucket = 'metagenomic-' + account + '-cn-northwest-1'
ddb_qc = 'metagenomic_qc'
ddb_metawrap = 'metagenomic_metawrap'
ddb_annotation = 'metagenomic_annotation'

table_qc = dynamodb.Table(ddb_qc)
table_metawrap = dynamodb.Table(ddb_metawrap)
table_annotation = dynamodb.Table(ddb_annotation)
# the state machine ARN
state_machine_arn = 'arn:aws-cn:states:'+region+':'+account+':stateMachine:metagenomics-analysis-pipeline'

wb = openpyxl.load_workbook('sample-info.xlsx')
sheet = wb['metagenomic']
# 以第一个sample做测试
sample = sheet.cell(row=2, column=1).value 
type = str(sheet.cell(row=2, column=2).value) 
print('sample: ', sample, 'type: ', type)

# init ddb table
table_qc.put_item(
       Item={
            'sample': sample,
            'threads': 16,
            'qc_time': 0,
            'status': 0
        }
    )

table_metawrap.put_item(
   Item={
        'sample': sample,
        'assembly_time': 0,
        'binning_time': 0,
        'refinement_time': 0,
        'type': type,
        'status': 0
    }
) 

table_annotation.put_item(
   Item={
        'sample': sample,
        'cdhit_time': 0,
        'coverm_time': 0,
        'drep_time': 0,
        'gtdbtk_time': 0,
        'metaphlan_time': 0,
        'prodigal_time': 0,
        'salmon_time': 0,
        'seqkit_time': 0,
        'type': type,
        'status': 0
    }
)

# define the input data
input = {
            'params': [
                {
                    'script': '/scripts/qc.sh',
                    'sample': sample,
                    'threads': '16',
                    'bucket': bucket,
                    'dbtable': ddb_qc
                },
                {
                    'script': '/scripts/metawrap-assembly.sh',
                    'sample': sample,
                    'threads': '96',
                    'memory': '185',
                    'type': type,
                    'bucket': bucket,
                    'dbtable': ddb_metawrap
                },
                {
                    'script': '/scripts/metawrap-binning.sh',
                    'sample': sample,
                    'threads': '32',
                    'memory': '58',
                    'type': type,
                    'bucket': bucket,
                    'dbtable': ddb_metawrap
                },
                {
                    'script': '/scripts/annotation.sh',
                    'sample': sample,
                    'threads': '48',
                    'memory': '90000',
                    'type': type,
                    'bucket': bucket,
                    'dbtable': ddb_annotation
                }
            ]
        }
input_str = json.dumps(input)
print(input_str)

milli = str(round(time.time() * 1000))

# start the execution
response = sfn.start_execution(
    stateMachineArn=state_machine_arn,
    input=input_str,
    name='metagenomic-analysis-'+milli
)

# srint the execution ARN
print(response['executionArn'])
:::

2.查看Step Functions中状态机执行状态：

![](/static/job-sfn-execution.png)

收到邮件通知，流程执行成功：
![](/static/job-sfn-sns.png)

每个执行步骤详细情况：
![](/static/job-sfn-pipeline.png)

查看DynamoDB表中每个步骤的任务执行状态信息，如果某个步骤的执行时间有异常，再去查看Batch任务中的日志进行分析：

![](/static/job-sfn-ddb.png)

查看S3桶中的每个步骤的结果文件：

![](/static/job-sfn-s3.png)