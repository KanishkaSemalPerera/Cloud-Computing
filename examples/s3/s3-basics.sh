#!/bin/bash
# S3 hands-on: secure bucket, versioning, lifecycle, upload, presigned URL, cleanup.
set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="lesson-s3-$ACCOUNT_ID"          # bucket names are GLOBALLY unique

# 1. Create (regions other than us-east-1 need a LocationConstraint)
aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"

# 2. Harden: block public access, default encryption, versioning
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled

# 3. Lifecycle rules
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" \
  --lifecycle-configuration file://lifecycle.json

# 4. Upload / list / sync
echo "hello v1" > demo.txt
aws s3 cp demo.txt "s3://$BUCKET/demo.txt"
echo "hello v2" > demo.txt
aws s3 cp demo.txt "s3://$BUCKET/demo.txt"
aws s3api list-object-versions --bucket "$BUCKET" --prefix demo.txt \
  --query "Versions[].{Id:VersionId,Latest:IsLatest}" --output table
mkdir -p site && echo "<h1>hi</h1>" > site/index.html
aws s3 sync site/ "s3://$BUCKET/site/"

# 5. Temporary share link (expires in 5 minutes) - no need to make anything public
aws s3 presign "s3://$BUCKET/demo.txt" --expires-in 300

# 6. Cleanup (versioned bucket: delete all versions first)
read -rp "Delete bucket $BUCKET now? [y/N] " yn
if [[ "$yn" == "y" ]]; then
  aws s3api delete-objects --bucket "$BUCKET" --delete "$(aws s3api list-object-versions \
    --bucket "$BUCKET" --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)" >/dev/null
  aws s3api delete-objects --bucket "$BUCKET" --delete "$(aws s3api list-object-versions \
    --bucket "$BUCKET" --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' --output json)" >/dev/null || true
  aws s3api delete-bucket --bucket "$BUCKET"
  echo "Deleted."
fi
rm -rf demo.txt site
