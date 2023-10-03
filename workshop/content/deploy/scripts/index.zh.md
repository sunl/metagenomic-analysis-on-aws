---
title : "任务脚本"
weight : 34
---

1.笔记本实例中新建一个终端

![](/static/notebook-terminal.png)

2.切到ec-user用户，安装EFS Client
:::code{showCopyAction=true showLineNumbers=false language=bash}
sudo su ec2-user
sudo yum install -y amazon-efs-utils
:::

![](/static/notebook-efs-utils.png)

3.在EFS服务中查看文件系统的连接方法

![](/static/notebook-efs-mount-1.png)
![](/static/notebook-efs-mount-2.png)

4.新建一个挂载点，如efs，挂载EFS文件系统到该挂载点
:::code{showCopyAction=true showLineNumbers=false language=bash}
mkdir efs
sudo mount -t efs -o tls fs-0ae39a6a17ce91cb3:/ efs
:::

5.df查看是否挂载成功
:::code{showCopyAction=true showLineNumbers=false language=bash}
df -h
:::

![](/static/notebook-efs-mount-3.png)

6.复制scripts目录下的脚本到EFS
:::code{showCopyAction=true showLineNumbers=false language=bash}
cp scripts/*.sh efs/
ll efs/
:::

![](/static/notebook-efs-scripts.png)