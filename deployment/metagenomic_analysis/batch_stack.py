from aws_cdk import (
    Stack, CfnOutput, Size,
    aws_iam as iam,
    aws_ec2 as ec2,
    aws_ecr as ecr,
    aws_batch as batch,
    aws_ecs as ecs
)
from constructs import Construct

class BatchStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, vpc, default_sg, file_system, repo, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # The code that defines your stack goes here
        lt_qc = ec2.LaunchTemplate(
            self, "LaunchTemplate",
            launch_template_name="lt_metagenomic_qc",
            block_devices = [ec2.BlockDevice(device_name="/dev/xvda",volume=ec2.BlockDeviceVolume.ebs(150,encrypted=True))])
        
        lt_metawrap = ec2.LaunchTemplate(
            self, "LaunchTemplate2",
            launch_template_name="lt_metagenomic_metawrap", 
            block_devices = [ec2.BlockDevice(device_name="/dev/xvda",volume=ec2.BlockDeviceVolume.ebs(200,encrypted=True))])

        lt_annotation = ec2.LaunchTemplate(
            self, "LaunchTemplate3",
            launch_template_name="lt_metagenomic_annotation", 
            block_devices = [ec2.BlockDevice(device_name="/dev/xvda",volume=ec2.BlockDeviceVolume.ebs(500,encrypted=True))])

        # Define compute environment 
        private_subnets = vpc.private_subnets
        compute_env_qc = batch.ManagedEc2EcsComputeEnvironment(self, "EnvQC", compute_environment_name="env-qc-test", vpc=vpc, 
            minv_cpus=0, maxv_cpus=1024, instance_types=[ec2.InstanceType("c6g.4xlarge")],launch_template=lt_qc, 
            security_groups=[default_sg], vpc_subnets=ec2.SubnetSelection(subnets=private_subnets), allocation_strategy=batch.AllocationStrategy.BEST_FIT,
            use_optimal_instance_classes=False)

        compute_env_assembly = batch.ManagedEc2EcsComputeEnvironment(self, "EnvAssembly", compute_environment_name="env-assembly-test", vpc=vpc, 
            minv_cpus=0, maxv_cpus=2048, instance_types=[ec2.InstanceType("c6g.24xlarge")],launch_template=lt_metawrap, 
            security_groups=[default_sg], vpc_subnets=ec2.SubnetSelection(subnets=private_subnets), allocation_strategy=batch.AllocationStrategy.BEST_FIT,
            use_optimal_instance_classes=False)

        compute_env_binning = batch.ManagedEc2EcsComputeEnvironment(self, "EnvBinning", compute_environment_name="env-binning-test", vpc=vpc, 
            minv_cpus=0, maxv_cpus=2048, instance_types=[ec2.InstanceType("c6g.8xlarge")],launch_template=lt_metawrap, 
            security_groups=[default_sg], vpc_subnets=ec2.SubnetSelection(subnets=private_subnets), allocation_strategy=batch.AllocationStrategy.BEST_FIT,
            use_optimal_instance_classes=False)

        compute_env_annotation = batch.ManagedEc2EcsComputeEnvironment(self, "EnvAnnotation", compute_environment_name="env--annotation-test", vpc=vpc, 
            minv_cpus=0, maxv_cpus=2048, instance_types=[ec2.InstanceType("c6g.12xlarge")],launch_template=lt_annotation, 
            security_groups=[default_sg], vpc_subnets=ec2.SubnetSelection(subnets=private_subnets), allocation_strategy=batch.AllocationStrategy.BEST_FIT,
            use_optimal_instance_classes=False)

        # Define job queue
        job_queue_qc = batch.JobQueue(self, "JobQueueQC", job_queue_name="q-qc-test", compute_environments=[{
                "computeEnvironment": compute_env_qc,
                "order": 1}])

        job_queue_assembly = batch.JobQueue(self, "JobQueueAssembly", job_queue_name="q-assembly-test", compute_environments=[{
                "computeEnvironment": compute_env_assembly,
                "order": 1}])

        job_queue_binning = batch.JobQueue(self, "JobQueueBinning", job_queue_name="q-binning-test", compute_environments=[{
                "computeEnvironment": compute_env_binning,
                "order": 1}])

        job_queue_annotation = batch.JobQueue(self, "JobQueueAnnotation", job_queue_name="q-annotation-test", compute_environments=[{
                "computeEnvironment": compute_env_annotation,
                "order": 1}])

        # Define job definition
        batch_job_role =  iam.Role(self,'BatchJobRole', assumed_by=iam.ServicePrincipal('ecs-tasks.amazonaws.com'), description =' IAM role for batch job')
        batch_job_role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name('AmazonS3FullAccess'))
        batch_job_role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name('AmazonDynamoDBFullAccess'))
        batch_job_role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name('AWSBatchFullAccess'))

        repo_name = repo.repository_name
        image_id_qc = ecs.ContainerImage.from_ecr_repository(repository=ecr.Repository.from_repository_name(self, "QCImage",repo_name), tag="qc")
        image_id_metawrap = ecs.ContainerImage.from_ecr_repository(repository=ecr.Repository.from_repository_name(self, "MetawrapImage",repo_name), tag="metawrap")
        image_id_annotation = ecs.ContainerImage.from_ecr_repository(repository=ecr.Repository.from_repository_name(self, "AnnotationImage",repo_name), tag="annotation")

        job_definition_qc = batch.EcsJobDefinition(self, "JobDefQC", job_definition_name="jd-qc-test", 
            parameters = {
                "script": "/scripts/qc.sh",
                "sample": "mud01.2020.11.S",
                "threads":"16",
                "bucket":"hyes",
                "dbtable":"metagenomic_qc"
            },
            container=batch.EcsEc2ContainerDefinition(self, "ContainerDefQC", 
                image=image_id_qc, job_role=batch_job_role,
                command=["sh","Ref::script","Ref::sample","Ref::threads","Ref::bucket","Ref::dbtable"],
                volumes=[batch.EcsVolume.efs(
                        name="efs",
                        file_system=file_system,
                        root_directory="/",
                        container_path="/scripts"
                    )],
                privileged=True,
                memory=Size.mebibytes(31000),
                cpu=16
            )
        )

        job_definition_assembly = batch.EcsJobDefinition(self, "JobDefAssembly", job_definition_name="jd-assembly-test", 
            parameters = {
                "script": "/scripts/metawrap-assembly.sh",
                "sample": "mud01.2020.11.S",
                "threads":"96",
                "memory":"248",
                "type":"1",
                "bucket":"hyes",
                "dbtable":"metagenomic_metawrap"
            },
            container=batch.EcsEc2ContainerDefinition(self, "ContainerDefAssembly", 
                image=image_id_metawrap, job_role=batch_job_role,
                command=["sh","Ref::script","Ref::sample","Ref::threads","Ref::memory","Ref::type","Ref::bucket","Ref::dbtable"],
                volumes=[batch.EcsVolume.efs(
                        name="efs",
                        file_system=file_system,
                        root_directory="/",
                        container_path="/scripts"
                    )],
                privileged=True,
                memory=Size.mebibytes(253000),
                cpu=96
            )
        )

        job_definition_binning = batch.EcsJobDefinition(self, "JobDefBinning", job_definition_name="jd-binning-test", 
            parameters = {
                "script": "/scripts/metawrap-binning.sh",
                "sample": "mud01.2020.11.S",
                "threads":"32",
                "memory":"58",
                "type":"1",
                "bucket":"hyes",
                "dbtable":"metagenomic_metawrap"
            },
            container=batch.EcsEc2ContainerDefinition(self, "ContainerDefBinning", 
                image=image_id_metawrap, job_role=batch_job_role,
                command=["sh","Ref::script","Ref::sample","Ref::threads","Ref::memory","Ref::type","Ref::bucket","Ref::dbtable"],
                volumes=[batch.EcsVolume.efs(
                        name="efs",
                        file_system=file_system,
                        root_directory="/",
                        container_path="/scripts"
                    )],
                privileged=True,
                memory=Size.mebibytes(63000),
                cpu=32
            )
        )

        job_definition_annotation = batch.EcsJobDefinition(self, "JobDefAnnotation", job_definition_name="jd-annotation-test", 
            parameters = {
                "script": "/scripts/annotation.sh",
                "sample": "mud01.2020.11.S",
                "threads":"48",
                "memory":"90000",
                "type":"1",
                "bucket":"hyes",
                "dbtable":"metagenomic_annotation"
            },
            container=batch.EcsEc2ContainerDefinition(self, "ContainerDefAnnotation", 
                image=image_id_annotation, job_role=batch_job_role,
                command=["sh","Ref::script","Ref::sample","Ref::threads","Ref::memory","Ref::type","Ref::bucket","Ref::dbtable"],
                volumes=[batch.EcsVolume.efs(
                        name="efs",
                        file_system=file_system,
                        root_directory="/",
                        container_path="/scripts"
                    )],
                privileged=True,
                memory=Size.mebibytes(95000),
                cpu=48
            )
        )