#!/bin/bash
# Build a Docker image and push it to Amazon ECR.
set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-2}"
REPO="lesson-web"
TAG="${1:-v1}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

# Create the repo once (scan on push = free vulnerability scan)
aws ecr describe-repositories --region "$REGION" --repository-names "$REPO" >/dev/null 2>&1 || \
  aws ecr create-repository --region "$REGION" --repository-name "$REPO" \
    --image-scanning-configuration scanOnPush=true --image-tag-mutability IMMUTABLE

# Docker login to ECR (token valid 12h)
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

docker build -t "$REPO:$TAG" .
docker tag "$REPO:$TAG" "$REGISTRY/$REPO:$TAG"
docker push "$REGISTRY/$REPO:$TAG"

echo "Pushed $REGISTRY/$REPO:$TAG  -> put this in task-definition.json \"image\""
