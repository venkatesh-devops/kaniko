import boto3
import json
import argparse

parser = argparse.ArgumentParser(description="Update Lambda function configurations from S3")
parser.add_argument('-c', '--config', help='Path to the lambda_configuration.json file', default='lambda_configuration.json', required=True)
parser.add_argument('--updated-functions', help='JSON string of updated functions and their MD5 hashes', required=True)


args = parser.parse_args()

with open(args.config, 'r') as config_file:
    functions = json.load(config_file)

updated_functions = json.loads(args.updated_functions)

    
aws_region = functions[0].get('region', '')

s3_client = boto3.client('s3', region_name=aws_region)
lambda_client = boto3.client('lambda', region_name=aws_region)

for function in functions:
    function_name = function['function_name']
    
    if function_name not in updated_functions:
        print(f"Skipping {function_name}, no code changes detected.")
        continue

    s3_key = function['s3_key']
    s3_bucket = function['s3_bucket']
    
    try:
        response = lambda_client.update_function_code(
            FunctionName=function_name,
            S3Bucket=s3_bucket,
            S3Key=s3_key
        )
        print(f'Updated {function_name}: {response}')
    except Exception as e:
        raise f"update {function_name} failed with error {e}"
