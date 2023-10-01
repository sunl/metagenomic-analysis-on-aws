---
title : "前提与准备工作"
weight : 31
---

# EC2准备
进行CDK安装需要依赖python,pip和npm环境。您可以使用可联网的本地开发环境或者Amazon EC2环境。本文以操作系统Amazon Linux 2023为例进行说明， 请登录:link[AWS中国区EC2控制台]{href="https://cn-northwest-1.console.amazonaws.cn/ec2/home?region=cn-northwest-1#Instances"}，启动一台新实例，如下：
![](/static/cdk-ec2.png)

# CDK安装部署
1.使用“ec2-user”用户以及保存的key pair文件（例如metagenomic.pem）登录到该EC2实例,该版本通常已经内置python3，先安装pip,git与npm等环境依赖
:::code{showCopyAction=true showLineNumbers=false language=bash}
sudo yum install pip git npm -y
:::
然后安装 AWS CDK
:::code{showCopyAction=true showLineNumbers=false language=bash}
sudo npm install -g aws-cdk
:::
下载部署代码，执行如下命令(注：中国区github可能有连接稳定性问题，您也可以将public repo的软件包手动从github下载下来)：
:::code{showCopyAction=true showLineNumbers=false language=bash}
git clone https://github.com/sunl/metagenomic-analysis-on-aws.git
:::
进入 metagenomic-analysis-on-aws目录，并切换到deployment目录下
