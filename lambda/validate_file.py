import json
import os
import boto3
from urllib.parse import unquote_plus

s3 = boto3.client("s3")
sfn = boto3.client("stepfunctions")

STATE_MACHINE_ARN = os.environ.get("STATE_MACHINE_ARN")


def lambda_handler(event, context):

    print("Received event:")
    print(json.dumps(event))

    record = event["Records"][0]

    bucket = record["s3"]["bucket"]["name"]
    key = unquote_plus(record["s3"]["object"]["key"])

    print(f"Processing: s3://{bucket}/{key}")

    # ---------------------------------
    # 1. Validate file extension
    # ---------------------------------

    if not key.lower().endswith(".csv"):
        raise ValueError(f"Invalid file type: {key}")

    # ---------------------------------
    # 2. Get file metadata
    # ---------------------------------

    response = s3.head_object(
        Bucket=bucket,
        Key=key
    )

    file_size = response["ContentLength"]

    # Reject empty file
    if file_size == 0:
        raise ValueError("File is empty")

    print(f"File size: {file_size} bytes")

    # ---------------------------------
    # 3. Validation passed
    # ---------------------------------

    payload = {
        "bucket": bucket,
        "key": key,
        "file_size": file_size
    }

    print("Validation successful")

    # Step Functions will be connected later
    if STATE_MACHINE_ARN:
        response = sfn.start_execution(
            stateMachineArn=STATE_MACHINE_ARN,
            input=json.dumps(payload)
        )

        print(
            f"Started Step Functions execution: "
            f"{response['executionArn']}"
        )

    return {
        "statusCode": 200,
        "body": json.dumps(payload)
    }