---
title : "业务场景及对应架构"
weight : 12
---

## 本方案适合的业务场景及对应架构

1.大规模批量任务分析

![](/static/arch-batch.png)

2.自动化工作流

![](/static/arch-pipeline.png)


## 主要用到的AWS服务
本方案主要用到了以下AWS服务：
- Batch：批量计算，自动计算资源调度
- EC2：适合各种计算需求的实例类型，Arm架构的Graviton实例提升性价比，Spot实例降低成本
- S3：数据存储，通过智能分层 优化成本
- ECR：容器镜像仓库
- DynamoDB：存储任务状态信息
- EFS：共享文件系统，存储任务运行脚本
- SageMaker Notebook：任务投递客户端
- Step Functions：自动化工作流
- SNS：邮件通知服务