#!/bin/bash
# CPU alarm on an EC2 instance -> SNS email.
# Usage: ./cloudwatch-alarm.sh i-0123456789abcdef0 you@example.com
set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-2}"
INSTANCE_ID="$1"
EMAIL="$2"

TOPIC_ARN=$(aws sns create-topic --region "$REGION" --name lesson-alerts --query TopicArn --output text)
aws sns subscribe --region "$REGION" --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$EMAIL"
echo "Check your inbox and CONFIRM the subscription."

# Alarm when average CPU > 80% for 2 consecutive 5-minute periods
aws cloudwatch put-metric-alarm --region "$REGION" \
  --alarm-name "high-cpu-$INSTANCE_ID" \
  --alarm-description "CPU > 80% for 10 minutes" \
  --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
  --statistic Average --period 300 --evaluation-periods 2 \
  --threshold 80 --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN" --ok-actions "$TOPIC_ARN"

# Test the notification path without stressing the CPU:
aws cloudwatch set-alarm-state --region "$REGION" --alarm-name "high-cpu-$INSTANCE_ID" \
  --state-value ALARM --state-reason "Testing alarm path"
