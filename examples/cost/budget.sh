#!/bin/bash
# DO THIS FIRST on any new AWS account: a monthly budget with email alerts.
# Usage: ./budget.sh you@example.com 10        (alert at 80% and 100% of $10/month)
set -euo pipefail
EMAIL="$1"
LIMIT="${2:-10}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws budgets create-budget --account-id "$ACCOUNT_ID" \
  --budget "{\"BudgetName\":\"monthly-$LIMIT-usd\",\"BudgetLimit\":{\"Amount\":\"$LIMIT\",\"Unit\":\"USD\"},
             \"TimeUnit\":\"MONTHLY\",\"BudgetType\":\"COST\"}" \
  --notifications-with-subscribers "[
    {\"Notification\":{\"NotificationType\":\"ACTUAL\",\"ComparisonOperator\":\"GREATER_THAN\",\"Threshold\":80,\"ThresholdType\":\"PERCENTAGE\"},
     \"Subscribers\":[{\"SubscriptionType\":\"EMAIL\",\"Address\":\"$EMAIL\"}]},
    {\"Notification\":{\"NotificationType\":\"FORECASTED\",\"ComparisonOperator\":\"GREATER_THAN\",\"Threshold\":100,\"ThresholdType\":\"PERCENTAGE\"},
     \"Subscribers\":[{\"SubscriptionType\":\"EMAIL\",\"Address\":\"$EMAIL\"}]}
  ]"
echo "Budget created: alert at 80% actual and 100% forecasted of \$$LIMIT."

# What did I spend this month, by service?
aws ce get-cost-and-usage \
  --time-period Start="$(date -u +%Y-%m-01)",End="$(date -u -d tomorrow +%Y-%m-%d)" \
  --granularity MONTHLY --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --query "ResultsByTime[0].Groups[].{Service:Keys[0],USD:Metrics.UnblendedCost.Amount}" --output table
