#!/usr/bin/env python3
import os

import aws_cdk as cdk

from metagenomic_analysis.batch_stack import BatchStack
from metagenomic_analysis.vpc_stack import VPCStack
from metagenomic_analysis.notebook_stack import NotebookStack

ACCOUNT = os.getenv('AWS_ACCOUNT_ID', '')
REGION = os.getenv('AWS_REGION', 'cn-nothwest-1')

app = cdk.App()
vpc_stack = VPCStack(app, "VPCStack", 
                     env=cdk.Environment(account=ACCOUNT, region=REGION))
batch_stack = BatchStack(app, "BatchStack", 
                         vpc=vpc_stack.vpc, 
                         default_sg=vpc_stack.default_sg, 
                         file_system=vpc_stack.file_system, 
                         repo=vpc_stack.repo,
                         env=cdk.Environment(account=ACCOUNT, region=REGION))
notebook_stack = NotebookStack(app, "NotebookStack", 
                               vpc=vpc_stack.vpc,
                               env=cdk.Environment(account=ACCOUNT, region=REGION))

app.synth()
