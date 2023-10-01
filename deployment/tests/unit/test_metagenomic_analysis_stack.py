import aws_cdk as core
import aws_cdk.assertions as assertions

from metagenomic_analysis.metagenomic_analysis_stack import MetagenomicAnalysisStack

# example tests. To run these tests, uncomment this file along with the example
# resource in metagenomic_analysis/metagenomic_analysis_stack.py
def test_sqs_queue_created():
    app = core.App()
    stack = MetagenomicAnalysisStack(app, "metagenomic-analysis")
    template = assertions.Template.from_stack(stack)

#     template.has_resource_properties("AWS::SQS::Queue", {
#         "VisibilityTimeout": 300
#     })
