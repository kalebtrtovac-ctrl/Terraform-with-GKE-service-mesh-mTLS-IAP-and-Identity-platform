#!/bin/bash

## RUN THIS SCRIPT BEFORE apply.sh TO ENSURE ALL REQUIRED APIS ARE ENABLED

# Path to service account keyfile and check if it exists
KEYFILE="./kaleb-demo-projectgke-477618-d9d2d70ce8c4.json"
if [[ ! -f "$KEYFILE" ]]; then
  echo "Keyfile not found: $KEYFILE" >&2
  exit 1
fi

# Check for required tools
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required but not installed" >&2
  exit 1
fi
if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is required but not installed" >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required but not installed or daemon not running" >&2
  exit 1
fi

## Authenticate with gcloud using the service account and set project
gcloud auth activate-service-account --key-file="$KEYFILE"
project_id=$(jq -r '.project_id' "./kaleb-demo-projectgke-477618-d9d2d70ce8c4.json")

echo "Enabling required API's for build"

gcloud config set project $project_id
gcloud services enable compute.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable dns.googleapis.com
gcloud services enable domains.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable servicenetworking.googleapis.com
gcloud services enable cloudkms.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable vpcaccess.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable certificatemanager.googleapis.com
gcloud services enable cloudbilling.googleapis.com
gcloud services enable storage-component.googleapis.com
gcloud services enable container.googleapis.com
gcloud services enable billingbudgets.googleapis.com 
gcloud services enable eventarc.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable recommender.googleapis.com 
gcloud services enable secretmanager.googleapis.com

echo "set project to $project_id and enabled required APIs successfully"