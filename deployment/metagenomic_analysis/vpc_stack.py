from aws_cdk import (
    Stack, CfnOutput, RemovalPolicy, 
    aws_ec2 as ec2,
    aws_ecr as ecr,
    aws_efs as efs,
    aws_dynamodb as ddb,
)
from constructs import Construct

class VPCStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        # The code that defines your stack goes here
        vpc = ec2.Vpc(self, "VPC", vpc_name ="MetagenomicVPC",
                           max_azs=99,
                           ip_addresses=ec2.IpAddresses.cidr("10.0.0.0/20"),
                           # configuration will create 3 groups in 2 AZs =  subnets.
                           subnet_configuration=[ec2.SubnetConfiguration(
                               subnet_type=ec2.SubnetType.PUBLIC,
                               name="Public",
                               cidr_mask=24
                            ), ec2.SubnetConfiguration(
                               subnet_type=ec2.SubnetType.PRIVATE_WITH_EGRESS,
                               name="Private",
                               cidr_mask=24
                            )
                           ],
                           nat_gateways=1,
                           )

        default_sg = ec2.SecurityGroup.from_security_group_id(self, "DefaultSG", vpc.vpc_default_security_group)  
        default_sg.add_ingress_rule(default_sg, ec2.Port.all_traffic())
        default_sg.add_egress_rule(ec2.Peer.any_ipv4(), ec2.Port.all_traffic(), "allow all outbound")

        # Create S3 endpoint
        s3_endpoint = vpc.add_gateway_endpoint("S3Endpoint", service=ec2.GatewayVpcEndpointAwsService.S3)

        # Create DynamoDB endpoint
        ddb_endpoint = vpc.add_gateway_endpoint("DynamoDBEndpoint", service=ec2.GatewayVpcEndpointAwsService.DYNAMODB)

        # create ECR repo  
        repo = ecr.Repository(self, "EcrRepo", repository_name="metagenomic", removal_policy=RemovalPolicy.DESTROY)

        # Create EFS file system
        efs_sg = ec2.SecurityGroup(self, "EFSSecurityGroup", security_group_name="efs_sg", vpc=vpc, allow_all_outbound=True)
        efs_sg.add_ingress_rule(peer=ec2.Peer.ipv4('10.0.0.0/20'), connection=ec2.Port.tcp(2049))
        file_system = efs.FileSystem(self, "EFSFileSystem", file_system_name="metagenomic_efs", vpc=vpc, 
            vpc_subnets=ec2.SubnetSelection(subnets=vpc.private_subnets), security_group=efs_sg, 
            allow_anonymous_access=True, removal_policy=RemovalPolicy.DESTROY)

        # Create DynamoDB tables
        ddb_table_qc = ddb.Table(self, "DDBTableQC", table_name="metagenomic_qc",
                              partition_key=ddb.Attribute(name="sample", type=ddb.AttributeType.STRING),
                              billing_mode=ddb.BillingMode.PAY_PER_REQUEST, # On-demand capacity
                              removal_policy=RemovalPolicy.DESTROY)
        ddb_table_metawrap = ddb.Table(self, "DDBTableMetawrap", table_name="metagenomic_metawrap",
                              partition_key=ddb.Attribute(name="sample", type=ddb.AttributeType.STRING),
                              billing_mode=ddb.BillingMode.PAY_PER_REQUEST, # On-demand capacity
                              removal_policy=RemovalPolicy.DESTROY)
        ddb_table_annotation = ddb.Table(self, "DDBTableAnnotation", table_name="metagenomic_annotation",
                              partition_key=ddb.Attribute(name="sample", type=ddb.AttributeType.STRING),
                              billing_mode=ddb.BillingMode.PAY_PER_REQUEST, # On-demand capacity
                              removal_policy=RemovalPolicy.DESTROY)
        
        self.vpc = vpc
        self.default_sg = default_sg
        self.file_system = file_system
        self.repo = repo

        CfnOutput(self, "Output", value=vpc.vpc_id)
        CfnOutput(self, "EFS", value=file_system.file_system_id)