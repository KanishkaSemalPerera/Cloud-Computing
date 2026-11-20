#!/bin/bash
# DynamoDB hands-on: table with partition + sort key, put, query, TTL.
set -euo pipefail
REGION="${AWS_REGION:-ap-southeast-2}"
T=lesson-orders

aws dynamodb create-table --region "$REGION" --table-name $T \
  --attribute-definitions AttributeName=userId,AttributeType=S AttributeName=orderId,AttributeType=S \
  --key-schema AttributeName=userId,KeyType=HASH AttributeName=orderId,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST
aws dynamodb wait table-exists --region "$REGION" --table-name $T

put() {
  aws dynamodb put-item --region "$REGION" --table-name $T --item "$1"
}
put '{"userId":{"S":"u#101"},"orderId":{"S":"2026-11-01#A1"},"total":{"N":"59.90"},"status":{"S":"PAID"}}'
put '{"userId":{"S":"u#101"},"orderId":{"S":"2026-11-15#B7"},"total":{"N":"12.00"},"status":{"S":"SHIPPED"}}'
put '{"userId":{"S":"u#202"},"orderId":{"S":"2026-10-30#C3"},"total":{"N":"99.00"},"status":{"S":"PAID"}}'

echo "Query: all November orders for u#101 (fast - uses the key)"
aws dynamodb query --region "$REGION" --table-name $T \
  --key-condition-expression "userId = :u AND begins_with(orderId, :m)" \
  --expression-attribute-values '{":u":{"S":"u#101"},":m":{"S":"2026-11"}}' \
  --query "Items[].{order:orderId.S,total:total.N,status:status.S}" --output table

echo "Scan with filter (reads the WHOLE table, then filters - avoid on big tables)"
aws dynamodb scan --region "$REGION" --table-name $T \
  --filter-expression "#s = :p" --expression-attribute-names '{"#s":"status"}' \
  --expression-attribute-values '{":p":{"S":"PAID"}}' --query "Count"

# TTL: items with an epoch-seconds "expiresAt" attribute are deleted automatically
aws dynamodb update-time-to-live --region "$REGION" --table-name $T \
  --time-to-live-specification "Enabled=true,AttributeName=expiresAt"

# Cleanup:  aws dynamodb delete-table --table-name lesson-orders
