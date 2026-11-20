#!/bin/bash
# Run the task definition as an ECS Service on Fargate.
# Prereqs: ecsTaskExecutionRole exists, 2 subnets + a security group allowing port 80.
# If you don't use the "secrets" block, remove it from task-definition.json first.
set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-2}"
SUBNETS="subnet-aaaaaaaa,subnet-bbbbbbbb"   # <-- change
SG_ID="sg-xxxxxxxx"                         # <-- change

aws ecs create-cluster --region "$REGION" --cluster-name lesson-cluster

aws ecs register-task-definition --region "$REGION" \
  --cli-input-json file://task-definition.json

aws ecs create-service --region "$REGION" \
  --cluster lesson-cluster \
  --service-name lesson-web \
  --task-definition lesson-web \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SG_ID],assignPublicIp=ENABLED}"
# Behind an ALB? add: --load-balancers targetGroupArn=<tg-arn>,containerName=web,containerPort=80

echo "Check tasks:  aws ecs list-tasks --cluster lesson-cluster"
# Rolling update after pushing a new image: register a new task def revision, then
#   aws ecs update-service --cluster lesson-cluster --service lesson-web --task-definition lesson-web
# Cleanup:
#   aws ecs update-service --cluster lesson-cluster --service lesson-web --desired-count 0
#   aws ecs delete-service --cluster lesson-cluster --service lesson-web
#   aws ecs delete-cluster --cluster lesson-cluster
