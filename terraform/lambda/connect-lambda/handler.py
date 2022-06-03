import boto3, os
from decimal import Decimal

def lambda_handler(event, context):
    connection_id = event["requestContext"]["connectionId"]
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(os.environ.get("DB_TABLE_NAME"))    

    ###### $connect
    if event["requestContext"]["eventType"] == "CONNECT":
        table.put_item(
            Item={
            'connection_Id': connection_id,
            'matched_truckid' : 3,
            'from_lon' : Decimal('129.086534'),
            'from_lat' : Decimal('35.231301'),
            'to_lon' : Decimal('129.1310207'),
            'to_lat' : Decimal('35.1730051')
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