---
title : "方案部署"
weight : 32
---

# 通过CDK部署解决方案
下面的命令将验证环境并生成CloudFormation模版
:::code{showCopyAction=true showLineNumbers=false language=bash}
cdk synth
:::
如下图:

![](/static/cdk-synth.png)

如果没有报错，则运行
:::code{showCopyAction=true showLineNumbers=false language=bash}
cdk deploy --all --require-approval never
:::
(注：--require-approval never表示不会在部署过程中提示选择“yes/no”自动往下运行，如果希望部署时确认是否部署则只需要运行“cdk deploy --all”即可)