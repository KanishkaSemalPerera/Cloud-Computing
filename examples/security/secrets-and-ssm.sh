#!/bin/bash
# Secrets Manager + SSM Parameter Store + Session Manager basics.
set -euo pipefail
REGION="${AWS_REGION:-ap-southeast-2}"

# ---------- Secrets Manager (secrets that rotate: DB passwords, API keys) ----------
aws secretsmanager create-secret --region "$REGION" \
  --name dev/lesson/db \
  --description "Lesson DB credentials" \
  --secret-string '{"username":"appuser","password":"'"$(openssl rand -base64 24)"'"}'

# Read it (your app does this via SDK using its IAM role - never commit secrets to git)
aws secretsmanager get-secret-value --region "$REGION" --secret-id dev/lesson/db \
  --query SecretString --output text

# ---------- SSM Parameter Store (config + simple secrets, standard tier is free) ----------
aws ssm put-parameter --region "$REGION" --name /lesson/dev/APP_ENV --type String --value dev
aws ssm put-parameter --region "$REGION" --name /lesson/dev/API_KEY --type SecureString --value "s3cr3t"
aws ssm get-parameters-by-path --region "$REGION" --path /lesson/dev --with-decryption \
  --query "Parameters[].{Name:Name,Value:Value}" --output table

# ---------- Session Manager: shell into EC2 with NO SSH key and NO port 22 ----------
# Requirements: SSM Agent (pre-installed on Amazon Linux), instance role with
# the AmazonSSMManagedInstanceCore policy, outbound HTTPS to SSM endpoints,
# and the Session Manager plugin installed on your laptop.
#   aws ssm start-session --target i-0123456789abcdef0

# ---------- Run Command: run a script on many instances by tag ----------
#   aws ssm send-command --document-name AWS-RunShellScript \
#     --targets Key=tag:Project,Values=cloud-lessons \
#     --parameters 'commands=["uptime","df -h"]'

# ---------- Cleanup ----------
#   aws secretsmanager delete-secret --secret-id dev/lesson/db --force-delete-without-recovery
#   aws ssm delete-parameters --names /lesson/dev/APP_ENV /lesson/dev/API_KEY
