---
title : "方案部署"
weight : 32
---

# 通过CDK部署解决方案
1.下面的命令将验证环境并生成CloudFormation模版
:::code{showCopyAction=true showLineNumbers=false language=bash}
cdk synth
:::
如下图:

![](/static/cdk-synth.png)

2.如果没有报错，则运行
:::code{showCopyAction=true showLineNumbers=false language=bash}
cdk deploy --all --require-approval never
:::
(注：--require-approval never表示不会在部署过程中提示选择“yes/no”自动往下运行，如果希望部署时确认是否部署则只需要运行“cdk deploy --all”即可)

3.CDK部署将提供4个CloudFormation堆栈以及相关资源，例如 VPC、EFS、DynamoDB、ECR、Batch、SageMaker Notebook和Step Functions状态机等，预计安装的部署时间约为18分钟
:::code{showCopyAction=true showLineNumbers=false language=bash}
VPCStack： 3分钟左右
BatchStack：4分钟左右
NotebookStack： 11分钟左右
StepFunctinosStack：1分钟左右
:::
部署过程如下:

![](/static/cdk-deploy.png)

直到所有的CloudFormatino都部署完毕，如下图:

![](/static/cdk-cloudformation.png)

4.你还会收到一封SNS订阅确认邮件，点击Confirm subscription后才能收到后续的通知邮件

![](/static/cdk-sns.png)