#!/bin/bash
# https://cloud.google.com/sdk/gcloud/reference/functions/deploy
source bin/env.sh

# exit if any subcommand has error
set -euxo pipefail

# Enable APIs used in the solution
gcloud services enable 'firestore.googleapis.com'
gcloud services enable 'pubsub.googleapis.com'
gcloud services enable 'cloudfunctions.googleapis.com'
gcloud services enable 'appengine.googleapis.com'
gcloud services enable 'cloudscheduler.googleapis.com'
gcloud services enable 'cloudbuild.googleapis.com'
gcloud services enable 'cloudtasks.googleapis.com'
gcloud app create --region=$GCP_REGION || echo "App already created, skip"
gcloud alpha firestore databases create --region=$GCP_REGION

# Create GCS bucket
gsutil mb gs://$BUCKET_NAME/ || echo "bucket already exists, skip creation"

# Set up pubsub for event notitication
gcloud pubsub topics create $TOPIC_EXTERNAL || echo "topic already exists"
gcloud logging sinks create bq_complete_sink pubsub.googleapis.com/projects/$PROJECT_ID/topics/$TOPIC_EXTERNAL \
     --log-filter='resource.type="bigquery_resource" AND protoPayload.methodName="jobservice.jobcompleted"' || echo "sink already exists, skip"
sink_service_account=$(gcloud logging sinks describe bq_complete_sink |grep writerIdentity| sed 's/writerIdentity: //')
echo "bq sink service account: $sink_service_account"
gcloud pubsub topics add-iam-policy-binding $TOPIC_EXTERNAL \
     --member $sink_service_account --role roles/pubsub.publisher

gsutil cp example/google-ads.yaml gs://$BUCKET_NAME/config/google-ads.yaml
gsutil cp example/data.csv gs://$BUCKET_NAME/input/input-example.txt

$PIP install "google-auth>=1.24.0" "google-cloud-firestore>=1.6.2"
BUCKET_NAME=$BUCKET_NAME GOOGLE_CLOUD_PROJECT=$PROJECT_ID $PYTHON src/config.py

# Deploy cloud functions
sh bin/deploy-functions.sh

INPUT_PATH="gs://$BUCKET_NAME/input"
echo "Deployment success, please upload input files to $INPUT_PATH every day."