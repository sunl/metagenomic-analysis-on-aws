---
title : "任务脚本"
weight : 332
---

把任务脚本复制到方案部署时创建的EFS文件系统中供任务执行的时候调用

1.笔记本实例中新建一个终端

![](/static/notebook-terminal.png)

2.执行如下命令切到ec-user用户，安装EFS Client
:::code{showCopyAction=true showLineNumbers=false language=bash}
sudo su ec2-user
sudo yum install amazon-efs-utils -y
:::

![](/static/notebook-efs-utils.png)

3.在EFS服务中查看文件系统的连接方法

![](/static/notebook-efs-mount-1.png)
![](/static/notebook-efs-mount-2.png)

4.新建一个挂载点，如efs，复制上一步的挂载命令挂载EFS文件系统到该挂载点，如：
:::code{showCopyAction=true showLineNumbers=false language=bash}
mkdir efs
sudo mount -t efs -o tls fs-01772b1f32ebb5cf8:/ efs
:::

5.df查看是否挂载成功
:::code{showCopyAction=true showLineNumbers=false language=bash}
df -h
:::

![](/static/notebook-efs-mount-3.png)

6.复制scripts目录下的脚本到EFS
:::code{showCopyAction=true showLineNumbers=false language=bash}
sudo chown ec2-user:ec2-user -R efs/
cp scripts/*.sh efs/
ll efs/
:::

![](/static/notebook-efs-scripts.png)