#!/bin/bash
export project_id="your_project_id"
export bucket=$project_id
export client_id="your_client_id.apps.googleusercontent.com"
export client_secret="your_client_secret"
export refresh_token="your_refresh_token"
export developer_token="your_developer_token"
export login_customer_id="1234567890"
export notification_email="your_email_address"

export gcs_location="US"
export region="us-central1"
export zone="us-central1-c"
export appengine_location="asia-northeast1"

CLOUDSDK_AUTH_ACCESS_TOKEN=$(gcloud auth application-default print-access-token) bash deploy.sh
