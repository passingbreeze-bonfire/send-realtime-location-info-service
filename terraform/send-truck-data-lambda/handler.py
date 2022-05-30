import json
import boto3
import os

def lambda_handler(event, context):
    kinesis_client = boto3.client('kinesis')

    kinesis_response = kinesis_client.put_record(
        StreamName=os.environ.get('streamname'),
        Data = bytes(json.dumps(event).encode('utf-8')),
        PartitionKey= os.environ.get('PartitionKey')
    )
    responseCode = kinesis_response['ResponseMetadata']['HTTPStatusCode']
    response = {
        'statusCode': responseCode,
        'headers' : {
            'content-type' : 'application/json'
        },
        'body': 'Put Records Successful' if 200 <= responseCode < 400 else 'Put Records Failed'
    }
    return response