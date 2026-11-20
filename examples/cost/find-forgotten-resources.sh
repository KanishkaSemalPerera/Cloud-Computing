#!/bin/bash
# Find the usual "why is my bill high?" resources across ALL regions.
set -uo pipefail

for R in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do
  EC2=$(aws ec2 describe-instances --region "$R" --filters Name=instance-state-name,Values=running \
        --query "length(Reservations[].Instances[])" --output text)
  NAT=$(aws ec2 describe-nat-gateways --region "$R" --filter Name=state,Values=available \
        --query "length(NatGateways)" --output text)
  EIP=$(aws ec2 describe-addresses --region "$R" --query "length(Addresses[?AssociationId==null])" --output text)
  VOL=$(aws ec2 describe-volumes --region "$R" --filters Name=status,Values=available \
        --query "length(Volumes)" --output text)
  ELB=$(aws elbv2 describe-load-balancers --region "$R" --query "length(LoadBalancers)" --output text 2>/dev/null || echo 0)
  RDS=$(aws rds describe-db-instances --region "$R" --query "length(DBInstances)" --output text 2>/dev/null || echo 0)
  EKS=$(aws eks list-clusters --region "$R" --query "length(clusters)" --output text 2>/dev/null || echo 0)
  TOTAL=$((EC2 + NAT + EIP + VOL + ELB + RDS + EKS))
  if [[ $TOTAL -gt 0 ]]; then
    printf "%-16s running-EC2=%s NAT=%s unattached-EIP=%s unattached-EBS=%s ALB/NLB=%s RDS=%s EKS=%s\n" \
      "$R" "$EC2" "$NAT" "$EIP" "$VOL" "$ELB" "$RDS" "$EKS"
  fi
done
echo "Done. Anything listed above is costing you money."
