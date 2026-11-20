"""
A tiny Lambda function that works behind API Gateway (HTTP API) and also
when triggered by an S3 upload event.

Deploy:
    zip function.zip handler.py
    aws lambda create-function --function-name lesson-hello \
      --runtime python3.12 --handler handler.lambda_handler \
      --role arn:aws:iam::123456789012:role/lesson-lambda-role \
      --zip-file fileb://function.zip

Test:
    aws lambda invoke --function-name lesson-hello \
      --payload fileb://event-api.json out.json && cat out.json
"""
import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# Code OUTSIDE the handler runs once per cold start - put SDK clients / config here.
GREETING = os.environ.get("GREETING", "Hello")


def lambda_handler(event, context):
    logger.info("event received: %s", json.dumps(event))

    # S3 "ObjectCreated" event
    if "Records" in event and event["Records"][0].get("eventSource") == "aws:s3":
        for record in event["Records"]:
            bucket = record["s3"]["bucket"]["name"]
            key = record["s3"]["object"]["key"]
            logger.info("new object uploaded: s3://%s/%s", bucket, key)
        return {"processed": len(event["Records"])}

    # API Gateway HTTP API (payload v2.0)
    params = event.get("queryStringParameters") or {}
    name = params.get("name", "DevOps intern")
    body = {
        "message": f"{GREETING}, {name}!",
        "requestId": context.aws_request_id,
        "remainingMs": context.get_remaining_time_in_millis(),
    }
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
