# Automatic Deployment Bash Script
# To deploy manually from your machine, run the following:
# CLOUDSDK_AUTH_ACCESS_TOKEN=$(gcloud auth application-default print-access-token) bash deploy.sh

# Exit if variable empty
set -u

TOPIC_SCHEDULE=SCHEDULE
TOPIC_EXTERNAL=SCHEDULE_EXTERNAL_EVENTS
SRC_DIR='src'
RUNTIME='python310'
MEMORY='2048MB'


fail() {
    echo "$@"
    exit 1
}


enable_service() {
    gcloud services enable $1 || fail "Unable to enable service $1 for project $project_id, please check if you have the permissions"
    echo "[Success] Enabled service $1"
}


create_appengine_and_firestore() {
    local appengine_location=$1
    gcloud app describe >/dev/null 2>&1

    if [ $? -ne 0 ] ; then
        gcloud app create --region=$appengine_location || fail "Error creating app engine in location $appengine_location"
        echo "[Success] Created app engine"
    else
        location=$(gcloud app describe | grep location)
        echo "[Success] App engine exists in $location."
    fi

    gcloud firestore databases create --region=$appengine_location || fail "Faled to create firestore for $project_id in $appengine_location"
    echo "[Success] Firestore"

    local appengine_service_account="${project_id}@appspot.gserviceaccount.com"
    gcloud projects add-iam-policy-binding $project_id \
        --member "serviceAccount:$appengine_service_account" --role roles/editor || fail "Failed to grand permission to $appengine_service_account"
    echo "[Success] App Engine Permission"
}


create_gcs_bucket() {
    local bucket=$1

    gcloud storage ls gs://$bucket >/dev/null 2>&1
    
    if [ $? -ne 0 ] ; then
        gcloud storage buckets create --location=$gcs_location "gs://$bucket" || fail "Unable to create bucket $bucket."
        echo "[Success] Created bucket $bucket"
    else
        echo "[Success] Bucket $bucket already exists, skip creation"
    fi
}


copy_google_ads_configufation_file() {
    gcloud storage cat gs://$bucket/config/google-ads.yaml >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "[Success] Google Ads Configuration file exists: gs://$bucket/config/google-ads.yaml"
    else
        cat <<EOF >/tmp/google-ads.yaml
developer_token: $developer_token
client_id: $client_id
client_secret: $client_secret
refresh_token: $refresh_token
login_customer_id: $login_customer_id
use_proto_plus: True
EOF
        gcloud storage cp /tmp/google-ads.yaml gs://$bucket/config/google-ads.yaml
        echo "Copy google-ads.yaml to gs://$bucket/config/google-ads.yaml"
        echo "Checking config file content:"
        gcloud storage cat gs://$bucket/config/google-ads.yaml || exit "Failed to copy config file"
        rm -f /tmp/google-ads.yaml
        echo "[Success] Google Ads Configuration checked."
    fi
}


load_config() {
    echo "Checking bare metal config"
    
    curl "https://firestore.googleapis.com/v1/projects/${project_id}/databases/(default)/documents/Config" \
       --header "Authorization: Bearer ${CLOUDSDK_AUTH_ACCESS_TOKEN}"  \
       --header 'Accept: application/json'  \
       --compressed 2>&1 | grep 'main'
    if [ $? -ne 0 ]; then
        local config=$(cat <<EOF
{"fields": {
    "bucket": {"stringValue": "${bucket}"},
    "max_concurrent_workers": {"integerValue": 3},
    "events_per_worker": {"integerValue": 20000},
    "events_per_batch": {"integerValue": 500},
    "notification_email": {"stringValue": "${notification_email}"}
}}
EOF
)
        
        echo "Initialize config: $config"
        curl --request POST \
            "https://firestore.googleapis.com/v1/projects/${project_id}/databases/(default)/documents/Config?documentId=main" \
            --header "Authorization: Bearer ${CLOUDSDK_AUTH_ACCESS_TOKEN}" \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
            --data "${config}" \
            --compressed

        echo "Checking config"
        curl "https://firestore.googleapis.com/v1/projects/${project_id}/databases/(default)/documents/Config" \
            --header "Authorization: Bearer ${CLOUDSDK_AUTH_ACCESS_TOKEN}"  \
            --header 'Accept: application/json'  \
            --compressed 2>&1 | grep 'main'

        if [ $? -ne 0 ]; then    
            fail "Unable to initialize Bare Metal config in Firestore for $project_id. Please check your permissions."
        fi

        echo "[Success] Configuration intialized."
    else
        echo "[Success] Config exists in Firestore."
    fi
}


setup_pubsub() {
    local topic_external=$1
    gcloud pubsub topics list | grep "$topic_external"

    if [ $? -eq 0 ]; then
        echo "[Success] topic exists $topic_external"
    else
        gcloud pubsub topics create $topic_external || fail "Unable to create pubsub topic $topic_external. Please check your permission settings."
        echo "[Success] Created pubsub topic $topic_external"
    fi

    bq_sink=bq_complete_sink
    gcloud logging sinks describe $bq_sink >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "[Success] BQ sink exists $bq_sink"
    else
        gcloud logging sinks create $bq_sink pubsub.googleapis.com/projects/$project_id/topics/$topic_external \
            --log-filter='resource.type="bigquery_resource" AND protoPayload.methodName="jobservice.jobcompleted"' || fail "Unable to create Log sink $bq_sink. Please check your permissions."
        echo "[Success] BQ sink created $bq_sink"
    fi

    local sink_service_account=$(gcloud logging sinks describe $bq_sink |grep writerIdentity| sed 's/writerIdentity: //')
    echo "bq sink service account: $sink_service_account"
    gcloud pubsub topics add-iam-policy-binding $topic_external \
        --member $sink_service_account --role roles/pubsub.publisher || fail "Unable to add access to $sink_service_account. Please check your permissions."
    echo "[Success] Set up Log sink for Biquery events."
}

# Set default project id
echo "GCP Project id: $project_id"
gcloud config set project $project_id

# Enable APIs used in the solution
enable_service 'firestore.googleapis.com'
enable_service 'pubsub.googleapis.com'
enable_service 'cloudfunctions.googleapis.com'
enable_service 'appengine.googleapis.com'
enable_service 'cloudscheduler.googleapis.com'
enable_service 'cloudbuild.googleapis.com'
enable_service 'cloudtasks.googleapis.com'

# Create GCS bucket
create_gcs_bucket $bucket

# Copy Google Ads configuration file to GCS
copy_google_ads_configufation_file

# Create firestore
create_appengine_and_firestore $appengine_location
load_config

# Create pubsub to get job complete notifications
setup_pubsub $TOPIC_EXTERNAL

# Copy sample data
gcloud storage cp example/data.csv gs://$bucket/input/data.csv.example

# Deploy Cloud Functions
gcloud functions deploy start --project $project_id --memory=$MEMORY --quiet --timeout=540 --runtime $RUNTIME --trigger-http --source $SRC_DIR || fail "Cloud Function deploy failed."
gcloud functions deploy send_single_event --project $project_id --memory=$MEMORY --quiet --timeout=540 --runtime $RUNTIME --trigger-http --source $SRC_DIR || fail "Cloud Function deploy failed."
gcloud functions deploy pingback_worker --project $project_id --memory=$MEMORY --quiet --timeout=540 --runtime $RUNTIME  --trigger-http --source $SRC_DIR || fail "Cloud Function deploy failed."

gcloud functions deploy scheduler --quiet --project $project_id --memory=$MEMORY --timeout=540 --runtime $RUNTIME --trigger-topic $TOPIC_SCHEDULE --source $SRC_DIR || fail "Cloud Function deploy failed."
gcloud functions deploy external_event_listener --project $project_id --memory=$MEMORY --quiet --timeout=540 --runtime $RUNTIME --trigger-topic $TOPIC_EXTERNAL --source $SRC_DIR || fail "Cloud Function deploy failed."

# Cronjobs
# https://cloud.google.com/scheduler/docs/configuring/cron-job-schedules
# For quick cron setting: https://crontab.guru/every-10-minutes
# Run bare metal upload job every 10 minutes
gcloud functions deploy cron --project $project_id --memory=$MEMORY --timeout=540 --runtime $RUNTIME --trigger-topic BARE_METAL_CRON --source src --quiet || fail "Cloud Function deploy failed."

gcloud scheduler jobs list | grep bare-metal-cronjob
if [ $? -eq 0 ]; then
    echo "[Success] Bare Metal Cronjob exists."
else
    gcloud scheduler jobs create pubsub bare-metal-cronjob \
        --schedule '*/10 * * * *' \
        --topic BARE_METAL_CRON \
        --message-body '{}' \
        --time-zone 'Asia/Shanghai' || fail "Unable to create cronjob, please check your permissions."
    echo "[Success] Bare Metal Cronjob created."
fi

# Run email notifications 
gcloud functions deploy email_cron --project $project_id --memory=$MEMORY --timeout=540 --runtime $RUNTIME --trigger-topic BARE_METAL_EMAIL_CRON --source src --quiet || fail "Cloud Function deploy failed."
gcloud scheduler jobs list | grep bare-metal-email-cronjob
if [ $? -eq 0 ]; then
    echo "[Success] Email Cronjob exists."
else
    gcloud scheduler jobs create pubsub bare-metal-email-cronjob \
        --schedule '5 9 * * *' \
        --topic BARE_METAL_EMAIL_CRON \
        --message-body '{}' \
        --time-zone 'Asia/Shanghai' || fail "Unable to create cronjob, please check your permissions."
    echo "[Success] Email Cronjob created."
fi

echo "[Sucess] Deployment success, please upload input files to gs://$bucket/input every day."
