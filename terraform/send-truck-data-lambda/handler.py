import json
import boto3
import os

def lambda_handler(event, context):
    kinesis_client = boto3.client('kinesis')

    response = kinesis_client.put_record(
        StreamName=os.environ.get('streamname'),
        Data = bytes(json.dumps(event).encode('utf-8')),
        PartitionKey= os.environ.get('PartitionKey')
    )

    return response