---
title : "参考数据库"
weight : 35
---

1.复制任务程序所需要的参考数据库到你自己的S3存储桶中
::alert[123456789012换成你自己的账户ID]

:::code{showCopyAction=true showLineNumbers=false language=bash}
aws s3 sync s3://hyes/ref_data/ s3://metagenomic-123456789012-cn-northwest-1/ref_data/ --request-payer requester
:::


![](/static/notebook-refdata.png)