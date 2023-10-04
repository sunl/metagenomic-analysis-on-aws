import os
from aws_cdk import (
    Stack,
    aws_sns as sns,
    aws_sns_subscriptions as subs,
    aws_stepfunctions as stepfunctions,
    aws_stepfunctions_tasks as tasks,
)
from constructs import Construct

EMAIL = os.getenv('EMAIL', '')

class StepFunctionsStack(Stack):

    def __init__(self, scope: Construct, construct_id: str, job0, job1, job2, job3, queue0, queue1, queue2, queue3, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)
        
        # Step Functions
        # Batch submit job states
        task_0 = tasks.BatchSubmitJob(self, "SubmitJobQC",
            job_definition_arn=job0.job_definition_arn,
            job_name="metagenomic-qc",
            job_queue_arn=queue0.job_queue_arn,
            result_path="$.DISCARD",
            payload=stepfunctions.TaskInput.from_json_path_at("$.params[0]")
        )
        task_1 = tasks.BatchSubmitJob(self, "SubmitJobAssembly",
            job_definition_arn=job1.job_definition_arn,
            job_name="metagenomic-assembly",
            job_queue_arn=queue1.job_queue_arn,
            result_path="$.DISCARD",
            payload=stepfunctions.TaskInput.from_json_path_at("$.params[1]")
        )
        task_2 = tasks.BatchSubmitJob(self, "SubmitJobBinning",
            job_definition_arn=job2.job_definition_arn,
            job_name="metagenomic-binning",
            job_queue_arn=queue2.job_queue_arn,
            result_path="$.DISCARD",
            payload=stepfunctions.TaskInput.from_json_path_at("$.params[2]")
        )
        task_3 = tasks.BatchSubmitJob(self, "SubmitJobAnnotation",
            job_definition_arn=job3.job_definition_arn,
            job_name="metagenomic-annotation",
            job_queue_arn=queue3.job_queue_arn,
            result_path="$.DISCARD",
            payload=stepfunctions.TaskInput.from_json_path_at("$.params[3]")
        )

        # Create SNS topic
        notify_topic = sns.Topic(self, "SuccessTopic", topic_name="metagenomic-analysis-notify", display_name="Metagenomic Analysis Notification")
        # Subscribe an email address to the topic
        notify_topic.add_subscription(subs.EmailSubscription(EMAIL))
        notify_success = tasks.SnsPublish(self, "MetagenomicAnalysisSuccessful", topic=notify_topic,
            message=stepfunctions.TaskInput.from_text("Metagenomic Analysis submitted through Step Functions Successful!"))
        notify_fail = tasks.SnsPublish(self, "MetagenomicAnalysisFail", topic=notify_topic,
            message=stepfunctions.TaskInput.from_text("Metagenomic Analysis submitted through Step Functions Failed!"))
        
        # State machine definition
        definition = stepfunctions.Chain.start(task_0.add_catch(handler=notify_fail, errors=["States.ALL"]))\
            .next(task_1.add_catch(handler=notify_fail, errors=["States.ALL"]))\
            .next(task_2.add_catch(handler=notify_fail, errors=["States.ALL"]))\
            .next(task_3.add_catch(handler=notify_fail, errors=["States.ALL"]))\
            .next(notify_success)
        
        sm = stepfunctions.StateMachine(self, "StateMachine", state_machine_name="metagenomics-analysis-pipeline", 
            definition_body=stepfunctions.DefinitionBody.from_chainable(definition)
        )