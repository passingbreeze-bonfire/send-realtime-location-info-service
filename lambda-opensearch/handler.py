import boto3
import json
import requests
from requests_aws4auth import AWS4Auth
import os
import mpu
from decimal import *

region = 'ap-northeast-2'
service = 'es'
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key, region, service, session_token=credentials.token)

host = os.environ.get("OPENSEARCH_DOMAIN") # The OpenSearch domain endpoint with https://
index = os.environ.get("OPENSEARCH_INDEX")
url = host + '/' + index + '/_search' # openSearch URL
destination_url = os.environ.get("DESTINATION_URL") # 고객에게 전송

# DynamoDB
resource = boto3.resource('dynamodb')
table = resource.Table(os.environ.get("DB_TABLE_NAME"))
client = boto3.client('apigatewaymanagementapi', endpoint_url=destination_url)
dynamodb_index=0
# Error Handling -> 'TypeError: Object of type Decimal is not JSON serializable'
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        # 👇️ if passed in object is instance of Decimal
        # convert it to a string
        if isinstance(obj, Decimal):
            return str(obj)
        # 👇️ otherwise use the default behavior
        return json.JSONEncoder.default(self, obj)

# Lambda execution starts here
def lambda_handler(event, context):

    resp = table.scan()
    trucks = resp['Items']

    for truck in trucks:
      # Put the user query into the query DSL for more accurate search results.
      # Note that certain fields are boosted (^).
      query = { 
        "size" : 1,
        "sort" : [
          { "timestamp": { "order" : "desc" , "unmapped_type" : "long"} }
        ],
        "query": {
          "match": {
              "truckId" : truck['matched_truckid']
          }
        }
      }

      # Elasticsearch 6.x requires an explicit Content-Type header
      headers = { "Content-Type": "application/json" }

      # Make the signed HTTP request
      r = requests.get(url, auth=awsauth, headers=headers, data=json.dumps(query, cls=DecimalEncoder))

      # Create the response and add some extra content to support CORS
      response = {
          "statusCode": 200,
          "headers": {
              "Access-Control-Allow-Origin": '*'
          },
          "isBase64Encoded": False
      }

      # Add the search results to the response
      payload = { }
      full_res = json.loads(r.text)
      res_truck = full_res['hits']['hits'][0]['_source']

      cur = { }
      cur['lon'] = res_truck['lon']
      cur['lat'] = res_truck['lat']

      dest = { }
      dest['lon'] = truck['to_lon']
      dest['lat'] = truck['to_lat']

      res_truck['arrive'] = chk_arrive(cur, dest)
      payload['text'] = json.dumps(res_truck)

      ## dr = requests.post(destination_url, json=payload, headers=headers) TEST용 SLACK 

      
      response = client.post_to_connection(ConnectionId=resp['Items'][dynamodb_index]['connection_Id'],Data=json.dumps(payload['text']))
      dynamodb_index=dynamodb_index+1
    return True

# Check if the truck has arrived
def chk_arrive(cur, dest):

    dist = mpu.haversine_distance((cur['lat'], cur['lon']), (dest['lat'], dest['lon']))
    dist_range = 20 / 1000

    if(dist_range > dist):
      return True
    else:
      return False
      