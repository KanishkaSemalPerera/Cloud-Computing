#!/bin/bash
# Azure CLI equivalents of the AWS labs.  Install: https://learn.microsoft.com/cli/azure/install-azure-cli
#   az login
set -euo pipefail

RG=lesson-rg
LOC=australiaeast
SUFFIX=$RANDOM

# Resource group = lifecycle container. Deleting it deletes EVERYTHING inside.
az group create --name $RG --location $LOC

# ---------- Network: VNet + subnet + NSG (≈ VPC + subnet + security group) ----------
az network vnet create -g $RG -n lesson-vnet --address-prefix 10.0.0.0/16 \
  --subnet-name web --subnet-prefix 10.0.1.0/24
az network nsg create -g $RG -n web-nsg
az network nsg rule create -g $RG --nsg-name web-nsg -n allow-http --priority 100 \
  --access Allow --protocol Tcp --direction Inbound --destination-port-ranges 80

# ---------- VM (≈ EC2) ----------
az vm create -g $RG -n lesson-vm --image Ubuntu2204 --size Standard_B1s \
  --vnet-name lesson-vnet --subnet web --nsg web-nsg \
  --admin-username azureuser --generate-ssh-keys \
  --custom-data '#!/bin/bash
apt-get update && apt-get install -y nginx'
az vm show -d -g $RG -n lesson-vm --query publicIps -o tsv

# ---------- Blob Storage (≈ S3) ----------
SA="lessonsa$SUFFIX"   # 3-24 lowercase letters/numbers, globally unique
az storage account create -g $RG -n $SA --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false
az storage container create --account-name $SA -n artifacts --auth-mode login
echo "hello" > hello.txt
az storage blob upload --account-name $SA -c artifacts -f hello.txt -n hello.txt --auth-mode login
# Note: --auth-mode login needs the "Storage Blob Data Contributor" role on the account.

# ---------- AKS (≈ EKS) ----------
# az aks create -g $RG -n lesson-aks --node-count 2 --node-vm-size Standard_B2s \
#   --enable-managed-identity --generate-ssh-keys
# az aks get-credentials -g $RG -n lesson-aks
# kubectl apply -f ../eks/app.yaml       # same Kubernetes manifests work!

# ---------- Entra ID + RBAC (≈ IAM) ----------
# Give a user read-only access to just this resource group:
# az role assignment create --assignee user@yourtenant.onmicrosoft.com \
#   --role Reader --scope $(az group show -n $RG --query id -o tsv)

# ---------- Cleanup: one command ----------
# az group delete -n $RG --yes --no-wait
