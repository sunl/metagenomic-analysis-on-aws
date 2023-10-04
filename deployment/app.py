#!/usr/bin/env python3
import os
import aws_cdk as cdk

from metagenomic_analysis.batch_stack import BatchStack
from metagenomic_analysis.vpc_stack import VPCStack
from metagenomic_analysis.notebook_stack import NotebookStack
from metagenomic_analysis.stepfunctions_stack import StepFunctionsStack

ACCOUNT = os.getenv('AWS_ACCOUNT_ID', '')
REGION = os.getenv('AWS_REGION', 'cn-nothwest-1')

app = cdk.App()
vpc_stack = VPCStack(app, "VPCStack", 
                     env=cdk.Environment(account=ACCOUNT, region=REGION))
batch_stack = BatchStack(app, "BatchStack", 
                         vpc=vpc_stack.vpc,
                         file_system=vpc_stack.file_system, 
                         repo_name=vpc_stack.repo_name,
                         env=cdk.Environment(account=ACCOUNT, region=REGION))
notebook_stack = NotebookStack(app, "NotebookStack", 
                               vpc=vpc_stack.vpc,
                               env=cdk.Environment(account=ACCOUNT, region=REGION))
stepfunctions_stack = StepFunctionsStack(app, "StepFunctionsStack",
                         job0=batch_stack.job_definition_qc,
                         job1=batch_stack.job_definition_assembly,
                         job2=batch_stack.job_definition_binning,
                         job3=batch_stack.job_definition_annotation,
                         queue0=batch_stack.job_queue_qc,
                         queue1=batch_stack.job_queue_assembly,
                         queue2=batch_stack.job_queue_binning,
                         queue3=batch_stack.job_queue_annotation,
                         env=cdk.Environment(account=ACCOUNT, region=REGION))

app.synth()