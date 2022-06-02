from opensearchpy import OpenSearch, RequestsHttpConnection, AWSV4SignerAuth
import boto3

import json, os, mpu, asyncio
from decimal import *

region = 'ap-northeast-2'
credentials = boto3.Session().get_credentials()
auth = AWSV4SignerAuth(credentials, region)

host, index = os.environ.get("OPENSEARCH_DOMAIN"), os.environ.get("OPENSEARCH_INDEX")
destination_url = os.environ.get("DESTINATION_URL") # 고객에게 전송

# DynamoDB
resource = boto3.resource('dynamodb')
table = resource.Table(os.environ.get("DB_TABLE_NAME"))
client = boto3.client('apigatewaymanagementapi', endpoint_url = destination_url)

# convert Decimal to string
class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
      return str(obj) if isinstance(obj, Decimal) else json.JSONEncoder.default(self, obj)

# Lambda execution starts here
def lambda_handler(event, context):
    resp = table.scan()
    trucks_loc = dict(map(connectionid_map_client, resp['Items']))
    print(trucks_loc)
    # Create the response and add some extra content to support CORS
    asyncio.run(async_handler(event, context, trucks_loc))

async def async_handler(event, context, trucks_loc):
    async for id, query_response in process_query(trucks_loc):
    # Add the search results to the response
        res_truck = query_response['hits']['hits'][0]['_source']
    
        begin, cur, dest = {}, {}, {}
        begin['lon'], begin['lat'] = float(trucks_loc[id]['from_lon']), float(trucks_loc[id]['from_lat'])
        cur['lon'], cur['lat'] = float(res_truck['location']['lon']), float(res_truck['location']['lat'])
        dest['lon'], dest['lat'] = float(trucks_loc[id]['to_lon']), float(trucks_loc[id]['to_lat'])
        
        res_truck['connection_Id'] = id
        res_truck['departure'] = chk_depart(begin, cur)
        res_truck['arrive'] = chk_arrive(cur, dest)
        payload = json.dumps(res_truck)

        client.post_to_connection(ConnectionId = id, Data = payload)
        # print(f"post result : {response}")

async def process_query(trucks):
    opensearch_client = OpenSearch(
        hosts = [{'host': host, 'port': 443}],
        http_auth = auth,
        use_ssl = True,
        verify_certs = True,
        connection_class = RequestsHttpConnection
    )
    dsl_query = { 
          "size" : 1,
          "sort" : [
            { "timestamp": { "order" : "desc" , "unmapped_type" : "long"} }
          ],
          "query": {
            "match": {
                "truckId" : ""
            }
        }
    }
    for clientId in trucks.keys():
        dsl_query['query']['match']['truckId'] = trucks[clientId]['matched_truckid']
        query_result = opensearch_client.search(
            body = dsl_query,
            index = index
        )
        print("Query result :", query_result)
        yield clientId, query_result

def connectionid_map_client(client_info):
    connection_Id = str(client_info.pop('connection_Id'))
    mapped = {k:v for k,v in client_info.items()}
    return connection_Id, mapped

# Check if the truck has arrived
def chk_arrive(cur, dest, dist_range = 0.02):
    dist = mpu.haversine_distance((cur['lat'], cur['lon']), (dest['lat'], dest['lon']))
    return dist_range > dist

# Check if the truck has departed
def chk_depart(cur, dest, dist_range = 0.02):
    dist = mpu.haversine_distance((cur['lat'], cur['lon']), (dest['lat'], dest['lon']))
    return dist_range < dist
    