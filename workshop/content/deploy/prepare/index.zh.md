---
title : "前提与准备工作"
weight : 31
---

# EC2准备
进行CDK安装需要依赖python,pip和npm环境。您可以使用可联网的本地开发环境或者Amazon EC2环境。本文以操作系统Amazon Linux 2023为例进行说明， 请登录:link[AWS中国区EC2控制台]{href="https://cn-northwest-1.console.amazonaws.cn/ec2/home?region=cn-northwest-1#Instances"}，启动一台新实例，如下:
![](/static/cdk-ec2.png)

# CDK安装
1.使用“ec2-user”用户以及保存的key pair文件（例如metagenomic.pem）登录到该EC2实例,该版本通常已经内置python3，先安装pip,git与npm等环境依赖:
:::code{showCopyAction=true showLineNumbers=false language=bash}
sudo yum install pip git npm -y
:::

2.然后安装 AWS CDK
:::code{showCopyAction=true showLineNumbers=false language=bash}
sudo npm install -g aws-cdk
:::

3.下载部署代码，执行如下命令(注：中国区github可能有连接稳定性问题，您也可以将public repo的软件包手动从github下载下来):
:::code{showCopyAction=true showLineNumbers=false language=bash}
git clone https://github.com/sunl/metagenomic-analysis-on-aws.git
:::

4.进入 metagenomic-analysis-on-aws目录，并切换到deployment目录下:
:::code{showCopyAction=true showLineNumbers=false language=bash}
cd metagenomic-analysis-on-aws/deployment
:::

5.安装所需的所有依赖项:
:::code{showCopyAction=true showLineNumbers=false language=bash}
pip install -r requirements.txt
:::
如果在中国区遇到下载慢的问题，可以通过清华的镜像源加速
:::code{showCopyAction=true showLineNumbers=false language=bash}
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
:::

6.将您的账号信息以及需要部署的Region ID导入到环境变量中，本workshop将方案部署在cn-northwest-1:
:::code{showCopyAction=true showLineNumbers=false language=bash}
export AWS_ACCOUNT_ID=XXXXXXXXXXXX
export AWS_REGION=cn-northwest-1
export AWS_ACCESS_KEY_ID=XXXXXXXXXXXXXXXX
export AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXX
:::

7.为CDK配置资源，备注：如果您之前安装过本解决方案，本次新安装请先确保您已经卸载所有组件，并且删除名为“cdk-hnb659fds-assets”开头的S3 bucket，以便后续的安装指令可以正常执行，执行以下命令:
:::code{showCopyAction=true showLineNumbers=false language=bash}
cdk bootstrap  
:::
![](/static/cdk-bootstrap.png)

如果遇到"/bin/sh: line 1: python: command not found"的错误，请参考如下方式为python创建一个符号链接:
:::code{showCopyAction=true showLineNumbers=false language=bash}
[ec2-user@ip-10-0-0-17 deployment]$ which python3
/usr/bin/python3
[ec2-user@ip-10-0-0-17 deployment]$ sudo ln -s /usr/bin/python3 /usr/bin/python
[ec2-user@ip-10-0-0-17 deployment]$ python -V
Python 3.9.16
:::