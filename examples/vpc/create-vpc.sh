#!/bin/bash
# Build a 2-AZ VPC by hand with the AWS CLI so you SEE every piece:
#   VPC -> subnets -> IGW -> route tables -> (optional) NAT gateway
# Prefer IaC (../cloudformation or ../terraform) for real work.
set -euo pipefail

REGION="${AWS_REGION:-ap-southeast-2}"
AZ1="${REGION}a"; AZ2="${REGION}b"
tag() { echo "ResourceType=$1,Tags=[{Key=Name,Value=$2},{Key=Project,Value=cloud-lessons}]"; }

VPC=$(aws ec2 create-vpc --region "$REGION" --cidr-block 10.0.0.0/16 \
  --tag-specifications "$(tag vpc lesson-vpc)" --query Vpc.VpcId --output text)
aws ec2 modify-vpc-attribute --region "$REGION" --vpc-id "$VPC" --enable-dns-hostnames
echo "VPC: $VPC"

# Subnets: public 10.0.1-2.0/24, private 10.0.11-12.0/24
PUB1=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC" --cidr-block 10.0.1.0/24 \
  --availability-zone "$AZ1" --tag-specifications "$(tag subnet public-a)" --query Subnet.SubnetId --output text)
PUB2=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC" --cidr-block 10.0.2.0/24 \
  --availability-zone "$AZ2" --tag-specifications "$(tag subnet public-b)" --query Subnet.SubnetId --output text)
PRI1=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC" --cidr-block 10.0.11.0/24 \
  --availability-zone "$AZ1" --tag-specifications "$(tag subnet private-a)" --query Subnet.SubnetId --output text)
PRI2=$(aws ec2 create-subnet --region "$REGION" --vpc-id "$VPC" --cidr-block 10.0.12.0/24 \
  --availability-zone "$AZ2" --tag-specifications "$(tag subnet private-b)" --query Subnet.SubnetId --output text)
for s in $PUB1 $PUB2; do
  aws ec2 modify-subnet-attribute --region "$REGION" --subnet-id "$s" --map-public-ip-on-launch
done

# Internet Gateway - this is what makes a subnet "public"
IGW=$(aws ec2 create-internet-gateway --region "$REGION" \
  --tag-specifications "$(tag internet-gateway lesson-igw)" --query InternetGateway.InternetGatewayId --output text)
aws ec2 attach-internet-gateway --region "$REGION" --vpc-id "$VPC" --internet-gateway-id "$IGW"

# Public route table: 0.0.0.0/0 -> IGW
PUB_RT=$(aws ec2 create-route-table --region "$REGION" --vpc-id "$VPC" \
  --tag-specifications "$(tag route-table public-rt)" --query RouteTable.RouteTableId --output text)
aws ec2 create-route --region "$REGION" --route-table-id "$PUB_RT" \
  --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW" >/dev/null
aws ec2 associate-route-table --region "$REGION" --route-table-id "$PUB_RT" --subnet-id "$PUB1" >/dev/null
aws ec2 associate-route-table --region "$REGION" --route-table-id "$PUB_RT" --subnet-id "$PUB2" >/dev/null

# Private route table: only the local route (no internet) until you add a NAT
PRI_RT=$(aws ec2 create-route-table --region "$REGION" --vpc-id "$VPC" \
  --tag-specifications "$(tag route-table private-rt)" --query RouteTable.RouteTableId --output text)
aws ec2 associate-route-table --region "$REGION" --route-table-id "$PRI_RT" --subnet-id "$PRI1" >/dev/null
aws ec2 associate-route-table --region "$REGION" --route-table-id "$PRI_RT" --subnet-id "$PRI2" >/dev/null

# Free S3 gateway endpoint: private subnets reach S3 without internet/NAT
aws ec2 create-vpc-endpoint --region "$REGION" --vpc-id "$VPC" \
  --service-name "com.amazonaws.$REGION.s3" --route-table-ids "$PRI_RT" >/dev/null

if [[ "${WITH_NAT:-no}" == "yes" ]]; then
  # NAT Gateway costs money every hour (~$0.05/h + data). Only for the lab, then delete!
  EIP=$(aws ec2 allocate-address --region "$REGION" --domain vpc --query AllocationId --output text)
  NAT=$(aws ec2 create-nat-gateway --region "$REGION" --subnet-id "$PUB1" --allocation-id "$EIP" \
    --query NatGateway.NatGatewayId --output text)
  aws ec2 wait nat-gateway-available --region "$REGION" --nat-gateway-ids "$NAT"
  aws ec2 create-route --region "$REGION" --route-table-id "$PRI_RT" \
    --destination-cidr-block 0.0.0.0/0 --nat-gateway-id "$NAT" >/dev/null
  echo "NAT: $NAT (EIP alloc $EIP)"
fi

cat <<EOF
Done.
  VPC         $VPC
  Public      $PUB1 $PUB2   (route 0.0.0.0/0 -> $IGW)
  Private     $PRI1 $PRI2   (no internet route$( [[ "${WITH_NAT:-no}" == "yes" ]] && echo ", NAT added"))
Inspect:  aws ec2 describe-route-tables --filters Name=vpc-id,Values=$VPC --output table
Cleanup:  easiest is VPC console -> select lesson-vpc -> Delete VPC (delete NAT + release EIP first)
EOF
