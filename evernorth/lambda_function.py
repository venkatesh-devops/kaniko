import json
import boto3
import datetime
import base64
import random
import string
from boto3.dynamodb.conditions import Attr

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('bef_Intent_Api_Dev')
current_time = datetime.datetime.now().isoformat()

def decode_payload(body):
    decoded_bytes = base64.b64decode(body)
    decoded_str = decoded_bytes.decode("ascii")
    return json.loads(decoded_str)

def dynamo_table_scan(filter_expression):
    get_response = table.scan(
        FilterExpression=filter_expression
    )
    items = get_response.get('Items', [])
    while 'LastEvaluatedKey' in get_response:
        paginate_response = table.scan(
            FilterExpression=filter_expression,
            ExclusiveStartKey=get_response['LastEvaluatedKey']
        )
        items.extend(paginate_response.get('Items', []))
    return items

def dynamodb_put_data(payload, intentid):
    intent_type_id = payload.get('intentTypeId')
    intent_key = payload.get('key', {})
    org_id, carrier_div, plan_id, state = (
        intent_key.get('orgId'),
        intent_key.get('carrierDiv'),
        intent_key.get('planId'),
        intent_key.get('state')
    )
    item = {
        'intentid': intentid,
        'intentTypeId': intent_type_id,
        'key': {
            'orgId': org_id,
            'carrierDiv': carrier_div,
            'planId': plan_id,
            'state': state
        },
        'create_date': current_time,
        'update_date': None
    }

    try:
        existing_item = table.get_item(Key={'intentid': item['intentid']}).get('Item')
        if existing_item:
            item['update_date'] = current_time
            item['create_date'] = existing_item['create_date']
        table.put_item(Item=item)
    except Exception as e:
        print(f"Error fetching item from DynamoDB: {str(e)}")

def generate_random_intentid():
    intentid_length = 24
    characters = string.ascii_lowercase + string.digits
    return ''.join(random.choice(characters) for _ in range(intentid_length))

def lambda_handler(event, context):
    try:
        request = event['requestContext']['http']
        if request['method'] == 'POST':
            payload = decode_payload(event['body'])
            intentid = generate_random_intentid()
            dynamodb_put_data(payload, intentid)
            return {
                'statusCode': 200,
                'body': json.dumps(f'Item inserted/updated successfully in DynamoDB with intent id {intentid}')
            }
        elif request['method'] == 'GET':
            path_parts = request['path'].split('/')
            intentid_param = path_parts[-1]
            intentid_filter_expression = Attr('intentid').eq(intentid_param)
            items = dynamo_table_scan(intentid_filter_expression)
            return {
                'statusCode': 200,
                'body': json.dumps(items)
            }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
