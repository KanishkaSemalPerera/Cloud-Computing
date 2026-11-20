#!/bin/bash
# Launch a free-tier-eligible EC2 web server with the AWS CLI.
# Usage: ./launch-ec2.sh            (uses your default VPC)
# Clean up afterwards with:  ./launch-ec2.sh cleanup
set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-2}"
NAME="lesson-web"
SG_NAME="lesson-web-sg"

if [[ "${1:-}" == "cleanup" ]]; then
  IDS=$(aws ec2 describe-instances --region "$REGION" \
    --filters "Name=tag:Name,Values=$NAME" "Name=instance-state-name,Values=pending,running,stopped" \
    --query "Reservations[].Instances[].InstanceId" --output text)
  [[ -n "$IDS" ]] && aws ec2 terminate-instances --region "$REGION" --instance-ids $IDS \
    && aws ec2 wait instance-terminated --region "$REGION" --instance-ids $IDS
  SG_ID=$(aws ec2 describe-security-groups --region "$REGION" \
    --filters "Name=group-name,Values=$SG_NAME" --query "SecurityGroups[0].GroupId" --output text)
  [[ "$SG_ID" != "None" ]] && aws ec2 delete-security-group --region "$REGION" --group-id "$SG_ID"
  echo "Cleaned up."
  exit 0
fi

# 1. Latest Amazon Linux 2023 AMI (from the public SSM parameter - never hard-code AMI IDs)
AMI_ID=$(aws ssm get-parameter --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)

# 2. Security group: allow HTTP from anywhere (no SSH - use SSM Session Manager instead)
VPC_ID=$(aws ec2 describe-vpcs --region "$REGION" --filters Name=is-default,Values=true \
  --query "Vpcs[0].VpcId" --output text)
SG_ID=$(aws ec2 create-security-group --region "$REGION" --group-name "$SG_NAME" \
  --description "Lesson web server" --vpc-id "$VPC_ID" --query GroupId --output text)
aws ec2 authorize-security-group-ingress --region "$REGION" --group-id "$SG_ID" \
  --protocol tcp --port 80 --cidr 0.0.0.0/0

# 3. Launch
INSTANCE_ID=$(aws ec2 run-instances --region "$REGION" \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --security-group-ids "$SG_ID" \
  --user-data file://user-data.sh \
  --metadata-options "HttpTokens=required" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$NAME},{Key=Project,Value=cloud-lessons}]" \
  --query "Instances[0].InstanceId" --output text)

echo "Launched $INSTANCE_ID - waiting until running..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances --region "$REGION" --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
echo "Open: http://$PUBLIC_IP   (give user-data ~1 minute to finish)"
