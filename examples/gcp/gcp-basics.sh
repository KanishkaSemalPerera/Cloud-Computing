#!/bin/bash
# Google Cloud equivalents of the AWS labs.  Install: https://cloud.google.com/sdk/docs/install
#   gcloud auth login
#   gcloud config set project YOUR_PROJECT_ID
set -euo pipefail

PROJECT=$(gcloud config get-value project)
REGION=australia-southeast1
ZONE=australia-southeast1-a

gcloud services enable compute.googleapis.com run.googleapis.com container.googleapis.com storage.googleapis.com

# ---------- Compute Engine VM (≈ EC2) ----------
gcloud compute instances create lesson-vm --zone=$ZONE --machine-type=e2-micro \
  --image-family=debian-12 --image-project=debian-cloud --tags=http-server \
  --metadata=startup-script='#!/bin/bash
apt-get update && apt-get install -y nginx'
# Firewall rules are on the VPC network and target instances by TAG (≈ security group)
gcloud compute firewall-rules create allow-http --network=default \
  --allow=tcp:80 --target-tags=http-server --source-ranges=0.0.0.0/0
gcloud compute instances describe lesson-vm --zone=$ZONE \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)'

# ---------- Cloud Storage (≈ S3) ----------
BUCKET="gs://lesson-$PROJECT"
gcloud storage buckets create $BUCKET --location=$REGION --uniform-bucket-level-access \
  --public-access-prevention
echo "hello" > hello.txt
gcloud storage cp hello.txt $BUCKET/
gcloud storage ls $BUCKET

# ---------- Cloud Run (≈ Fargate/App Runner, scales to zero) ----------
gcloud run deploy hello --image=us-docker.pkg.dev/cloudrun/container/hello \
  --region=$REGION --allow-unauthenticated
# Deploy your own code straight from source (uses Cloud Build + Dockerfile/buildpacks):
#   gcloud run deploy my-app --source . --region=$REGION

# ---------- GKE Autopilot (≈ EKS with Fargate) ----------
# gcloud container clusters create-auto lesson-gke --region=$REGION
# gcloud container clusters get-credentials lesson-gke --region=$REGION
# kubectl apply -f ../eks/app.yaml

# ---------- IAM: least-privilege service account ----------
# gcloud iam service-accounts create app-reader
# gcloud storage buckets add-iam-policy-binding $BUCKET \
#   --member=serviceAccount:app-reader@$PROJECT.iam.gserviceaccount.com --role=roles/storage.objectViewer

# ---------- Cleanup ----------
# gcloud compute instances delete lesson-vm --zone=$ZONE -q
# gcloud compute firewall-rules delete allow-http -q
# gcloud run services delete hello --region=$REGION -q
# gcloud storage rm -r $BUCKET
