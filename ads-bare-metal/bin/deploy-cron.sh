#!/bin/bash
source bin/env.sh

# exit if any subcommand has error
set -euxo pipefail

echo "deploying cronjob for project $PROJECT_ID"
gcloud functions deploy cron --memory=2048MB --timeout=540 --runtime python37 --trigger-topic BARE_METAL_CRON --source src --quiet
gcloud functions deploy email_cron --memory=2048MB --timeout=540 --runtime python37 --trigger-topic BARE_METAL_EMAIL_CRON --source src --quiet


# https://cloud.google.com/scheduler/docs/configuring/cron-job-schedules
# For quick cron setting: https://crontab.guru/every-10-minutes
gcloud beta scheduler jobs create pubsub run-bare-metal \
    --schedule '*/10 * * * *' \
    --topic BARE_METAL_CRON \
    --message-body '{}' \
    --time-zone 'Asia/Shanghai' || echo "cron already exist, skip"

# run everyday at 00:05
gcloud beta scheduler jobs create pubsub run-bare-metal-email \
    --schedule '5 0 * * *' \
    --topic BARE_METAL_EMAIL_CRON \
    --message-body '{}' \
    --time-zone 'Asia/Shanghai' || echo "cron already exist, skip"
