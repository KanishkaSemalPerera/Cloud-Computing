#!/bin/bash
# SNS -> 2 SQS queues (fan-out) with a dead-letter queue.
# Needs: aws cli v2, python3 (only used to build JSON safely)
set -euo pipefail
REGION="${AWS_REGION:-ap-southeast-2}"

TOPIC_ARN=$(aws sns create-topic --region "$REGION" --name order-created --query TopicArn --output text)

# Dead-letter queue: messages land here after 3 failed receives
DLQ_URL=$(aws sqs create-queue --region "$REGION" --queue-name orders-dlq --query QueueUrl --output text)
DLQ_ARN=$(aws sqs get-queue-attributes --region "$REGION" --queue-url "$DLQ_URL" \
  --attribute-names QueueArn --query Attributes.QueueArn --output text)

for Q in billing shipping; do
  URL=$(aws sqs create-queue --region "$REGION" --queue-name "orders-$Q" --query QueueUrl --output text)
  ARN=$(aws sqs get-queue-attributes --region "$REGION" --queue-url "$URL" \
    --attribute-names QueueArn --query Attributes.QueueArn --output text)

  # Queue attributes: DLQ redrive + a policy allowing ONLY our SNS topic to send
  ATTRS=$(python3 - "$ARN" "$TOPIC_ARN" "$DLQ_ARN" <<'PY'
import json, sys
queue_arn, topic_arn, dlq_arn = sys.argv[1:]
policy = {
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "sns.amazonaws.com"},
        "Action": "sqs:SendMessage",
        "Resource": queue_arn,
        "Condition": {"ArnEquals": {"aws:SourceArn": topic_arn}},
    }],
}
redrive = {"deadLetterTargetArn": dlq_arn, "maxReceiveCount": "3"}
print(json.dumps({"Policy": json.dumps(policy), "RedrivePolicy": json.dumps(redrive),
                  "VisibilityTimeout": "30"}))
PY
)
  aws sqs set-queue-attributes --region "$REGION" --queue-url "$URL" --attributes "$ATTRS"

  aws sns subscribe --region "$REGION" --topic-arn "$TOPIC_ARN" --protocol sqs \
    --notification-endpoint "$ARN" --attributes RawMessageDelivery=true >/dev/null
  echo "orders-$Q subscribed"
done

# Publish ONE message -> it appears in BOTH queues
aws sns publish --region "$REGION" --topic-arn "$TOPIC_ARN" --message '{"orderId":"A1","total":59.90}' >/dev/null

for Q in billing shipping; do
  URL=$(aws sqs get-queue-url --region "$REGION" --queue-name "orders-$Q" --query QueueUrl --output text)
  echo "--- orders-$Q ---"
  aws sqs receive-message --region "$REGION" --queue-url "$URL" --wait-time-seconds 10 \
    --query "Messages[0].[Body,ReceiptHandle]" --output text > /tmp/msg.txt
  cut -f1 /tmp/msg.txt
  # A consumer MUST delete the message after processing, otherwise it becomes visible again
  aws sqs delete-message --region "$REGION" --queue-url "$URL" --receipt-handle "$(cut -f2 /tmp/msg.txt)"
done

# Cleanup:
#   aws sns delete-topic --topic-arn <arn>
#   for q in orders-billing orders-shipping orders-dlq; do
#     aws sqs delete-queue --queue-url $(aws sqs get-queue-url --queue-name $q --query QueueUrl --output text); done
