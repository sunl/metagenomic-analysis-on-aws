from aws_cdk import (
    Stack, CfnOutput,
    aws_iam as iam,
    aws_sagemaker as sagemaker,
)
from constructs import Construct

class NotebookStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, vpc, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # Sagemaker notebook
        notebook_job_role =  iam.Role(self,'NotebookRole',assumed_by=iam.ServicePrincipal('sagemaker.amazonaws.com'))
        notebook_job_role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name('AmazonS3FullAccess'))
        notebook_job_role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name('AmazonDynamoDBFullAccess'))
        notebook_job_role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name('AmazonEC2ContainerRegistryFullAccess'))
        notebook_job_role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name('AWSBatchFullAccess'))
        notebook_job_role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name('AWSStepFunctionsFullAccess'))
        notebook_job_role.add_managed_policy(iam.ManagedPolicy.from_aws_managed_policy_name('AmazonSageMakerFullAccess'))    
        notebook = sagemaker.CfnNotebookInstance(self, "Notebook", instance_type="ml.t3.medium", role_arn=notebook_job_role.role_arn,
            notebook_instance_name="metagenomic",subnet_id=vpc.private_subnets[0].subnet_id, security_group_ids=[vpc.vpc_default_security_group],
            volume_size_in_gb=50, direct_internet_access="Disabled",
            default_code_repository="https://github.com/sunl/metagenomic-analysis-on-aws/"
        )

        CfnOutput(self, "NotebookInstanceName", value=notebook.notebook_instance_name)