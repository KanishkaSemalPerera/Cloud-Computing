#!/bin/bash
# Create a small PostgreSQL RDS instance with an AWS-managed master password
# (stored + rotated in Secrets Manager automatically).
# Free tier: db.t3.micro / db.t4g.micro, 20 GB, Single-AZ.
set -euo pipefail
REGION="${AWS_REGION:-ap-southeast-2}"
SUBNETS="subnet-aaaaaaaa subnet-bbbbbbbb"   # <-- 2 PRIVATE subnets in different AZs
DB_SG="sg-xxxxxxxx"                          # <-- allows 5432 only from the app SG

aws rds create-db-subnet-group --region "$REGION" \
  --db-subnet-group-name lesson-db-subnets \
  --db-subnet-group-description "private DB subnets" \
  --subnet-ids $SUBNETS

aws rds create-db-instance --region "$REGION" \
  --db-instance-identifier lesson-pg \
  --engine postgres \
  --db-instance-class db.t4g.micro \
  --allocated-storage 20 --storage-type gp3 \
  --master-username dbadmin \
  --manage-master-user-password \
  --db-subnet-group-name lesson-db-subnets \
  --vpc-security-group-ids "$DB_SG" \
  --no-publicly-accessible \
  --storage-encrypted \
  --backup-retention-period 7 \
  --deletion-protection
  # Production: add --multi-az

aws rds wait db-instance-available --region "$REGION" --db-instance-identifier lesson-pg
aws rds describe-db-instances --region "$REGION" --db-instance-identifier lesson-pg \
  --query "DBInstances[0].{Endpoint:Endpoint.Address,Secret:MasterUserSecret.SecretArn,MultiAZ:MultiAZ}"

# Read replica (scales READS, async):
#   aws rds create-db-instance-read-replica --db-instance-identifier lesson-pg-ro \
#     --source-db-instance-identifier lesson-pg
# Cleanup:
#   aws rds modify-db-instance --db-instance-identifier lesson-pg --no-deletion-protection --apply-immediately
#   aws rds delete-db-instance --db-instance-identifier lesson-pg --skip-final-snapshot
