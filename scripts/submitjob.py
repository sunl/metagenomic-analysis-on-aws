import openpyxl
import boto3
import re

wb = openpyxl.load_workbook('test.xlsx')
sheet = wb['Metagenomic(test)']  
#sheet = wb.active

script = '/scripts/run.sh'
dbtable = 'ljh'
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ljh')

bucket = 'zju-ljh'
batch = boto3.client('batch')

jobdef='jd-ljh:1'
jobqueues=['q-ljh','q-ljh-2','q-ljh-3','q-ljh-4','q-ljh-5','q-ljh-6']

for row in sheet.iter_rows(min_row=2):
    srr = row[0].value
    size = row[7].value
    if size <= 20000: 
        threads=4
        memory='7500'
        jobqueue=jobqueues[0]
    elif size <= 30000: 
        threads=4
        memory='7500'
        jobqueue=jobqueues[1]
    elif size <= 60000: 
        threads=8
        memory='15000'
        jobqueue=jobqueues[2]
    elif size <= 80000: 
        threads=8
        memory='15000'
        jobqueue=jobqueues[3]
    elif size <= 100000: 
        threads=8
        memory='15000'
        jobqueue=jobqueues[4]
    else: 
        threads=8
        memory='15000'
        jobqueue=jobqueues[5]

    # init ddb table
    table.put_item(
       Item={
            'srr': srr,
            'size': size,
            'threads': threads,
            's3uri': '',
            'dl_time': 0,
            'extract_time': 0,
            'process_time': 0,
            'total_time':0,
            'paired': 0,
            'seqkit_result': '',
            'status': 0
        }
    )
    
    # submit jobs
    jobname = srr + '-' + str(threads)
    print('jobname: ', jobname, 'queue: ', jobqueue)
    params = {
        'script':'/scripts/run.sh',
        'srr':srr,
        'threads':str(threads),
        'dbtable':dbtable,
        'bucket':bucket
    }
    resourceRequirements = [
        {
            'value':str(threads),
            'type':'VCPU'
        },
        {
            'value':memory,
            'type':'MEMORY'
        },
    ]
    response = batch.submit_job(
        jobName=jobname,
        jobQueue=jobqueue,
        jobDefinition=jobdef,
        parameters=params,
        containerOverrides={
            'resourceRequirements':resourceRequirements
        }
    )
    print(response)