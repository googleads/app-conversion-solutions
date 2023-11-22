#!/bin/bash
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

echo "Update Success"
