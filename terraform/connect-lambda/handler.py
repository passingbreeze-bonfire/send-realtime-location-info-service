import json
import boto3
import os
import logging

def lambda_handler(event, context):
    connection_id = event["requestContext"]["connectionId"]
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('Connection')    

    ###### $connect
    if event["requestContext"]["eventType"] == "CONNECT":
        table.put_item(
            Item={
            'connection_Id': connection_id,
            'matched_truckid' : 5,
            'from_lon' : 140,
            'from_lat' : 40,
            'to_lon' : 100,
            'to_lat' : 60
            }
        )
        return {"statusCode": 200, "body": "Connect successful."}

    ###### $disconnect
    elif event['requestContext']['eventType'] == "DISCONNECT":
        table.delete_item(Key={'connection_Id': connection_id})
        return {"statusCode": 200, "body": "Disconnect successful."}

    ###### $default    
    else:
        return {"statusCode": 500, "body": "Unrecognized eventType."}