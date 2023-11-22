#!/bin/bash
source bin/env.sh

# exit if any subcommand has error
set -euxo pipefail

gcloud functions deploy start --project $PROJECT_ID --quiet --timeout=540 --runtime python37 --trigger-http --source $SRC_DIR
gcloud functions deploy send_single_event --project $PROJECT_ID --quiet --timeout=540 --runtime python37 --trigger-http --source $SRC_DIR
gcloud functions deploy pingback_worker --project $PROJECT_ID --quiet --timeout=540 --runtime python37  --trigger-http --source $SRC_DIR
gcloud functions deploy scheduler --quiet --project $PROJECT_ID --timeout=540 --runtime python37 --trigger-topic $TOPIC_SCHEDULE --source $SRC_DIR
gcloud functions deploy external_event_listener --project $PROJECT_ID --quiet --timeout=540 --runtime python37 --trigger-topic $TOPIC_EXTERNAL --source $SRC_DIR