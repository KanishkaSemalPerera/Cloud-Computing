#!/bin/bash
# Create a Launch Template + Auto Scaling Group + target-tracking policy.
# Prereqs: a security group ID and two subnet IDs in different AZs.
set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-2}"
SG_ID="sg-xxxxxxxx"                         # <-- change
SUBNETS="subnet-aaaaaaaa,subnet-bbbbbbbb"   # <-- change (2 AZs)

AMI_ID=$(aws ssm get-parameter --region "$REGION" \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)

USER_DATA=$(base64 -w0 ../ec2/user-data.sh)

# 1. Launch template = "how to build one instance"
aws ec2 create-launch-template --region "$REGION" \
  --launch-template-name lesson-web-lt \
  --launch-template-data "{
    \"ImageId\": \"$AMI_ID\",
    \"InstanceType\": \"t3.micro\",
    \"SecurityGroupIds\": [\"$SG_ID\"],
    \"UserData\": \"$USER_DATA\",
    \"MetadataOptions\": {\"HttpTokens\": \"required\"},
    \"TagSpecifications\": [{\"ResourceType\": \"instance\",
      \"Tags\": [{\"Key\": \"Name\", \"Value\": \"lesson-asg-web\"}]}]
  }"

# 2. Auto Scaling Group = "keep between 2 and 4 of them running across AZs"
aws autoscaling create-auto-scaling-group --region "$REGION" \
  --auto-scaling-group-name lesson-web-asg \
  --launch-template "LaunchTemplateName=lesson-web-lt,Version=\$Latest" \
  --min-size 2 --desired-capacity 2 --max-size 4 \
  --vpc-zone-identifier "$SUBNETS" \
  --health-check-type EC2 --health-check-grace-period 120
# Behind an ALB? add:  --target-group-arns <tg-arn> --health-check-type ELB

# 3. Scaling policy = "keep average CPU around 50%"
aws autoscaling put-scaling-policy --region "$REGION" \
  --auto-scaling-group-name lesson-web-asg \
  --policy-name cpu50 \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration file://target-tracking-policy.json

echo "Done. Watch it:  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names lesson-web-asg"
# Cleanup:
#   aws autoscaling delete-auto-scaling-group --auto-scaling-group-name lesson-web-asg --force-delete
#   aws ec2 delete-launch-template --launch-template-name lesson-web-lt
