provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
  access_token = var.access_token
}

/* APIs */
resource "google_project_service" "bigquery" {
  service = "bigquery.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "firestore" {
  service = "firestore.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "pubsub" {
  service = "pubsub.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "cloudfunction" {
  service = "cloudfunctions.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "appengine" {
  service = "appengine.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "cloudscheduler" {
  service = "cloudscheduler.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "cloudbuild" {
  service = "cloudbuild.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "cloudtasks" {
  service = "cloudtasks.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "sheets" {
  service = "sheets.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "drive" {
  service = "drive.googleapis.com"
  disable_dependent_services = true
}

resource "google_storage_bucket" "gcs_bucket" {
  force_destroy               = false
  location                    = var.gcs_location
  name                        = var.bucket
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
}
/* End APIs */

/* Permissions */
resource "google_project_iam_member" "appengine" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${var.project_id}@appspot.gserviceaccount.com"
  
  depends_on = [
    google_app_engine_application.appengine
  ]
}
/* End Permissions */

/* Firestore */
resource "google_app_engine_application" "appengine" {
  project         = var.project_id
  location_id     = var.appengine_location
  database_type   = "CLOUD_FIRESTORE"
  
  depends_on = [
    google_project_service.appengine
  ]
}

resource "google_firestore_document" "firestore_config" {
  project     = var.project_id
  collection  = "Config"
  document_id = "main"
  fields      = jsonencode({
    bucket = {stringValue = var.bucket},
    max_concurrent_workers = {integerValue = 3},
    events_per_worker = {integerValue = 20000},
    events_per_batch = {integerValue = 500},
    notification_email = {stringValue = var.notification_email},
  })
  
  lifecycle {
    ignore_changes = all
  }
  
  depends_on = [
    google_app_engine_application.appengine
  ]
}
/* End Firestore */

/* PubSub */
resource "google_pubsub_topic" "pubsub_schedule" {
  name    = "SCHEDULE"
}

resource "google_pubsub_topic" "pubsub_external" {
  name    = "SCHEDULE_EXTERNAL_EVENTS"
}

resource "google_pubsub_topic" "pubsub_cronjob" {
  name    = "BARE_METAL_CRON"
}

resource "google_pubsub_topic" "pubsub_email_cronjob" {
  name    = "BARE_METAL_EMAIL_CRON"
}
/* End PubSub */

/* Log Sink */
resource "google_logging_project_sink" "bq_complete_sink" {
  destination            = "pubsub.googleapis.com/projects/${var.project_id}/topics/${google_pubsub_topic.pubsub_external.name}"
  filter                 = "resource.type=\"bigquery_resource\" AND protoPayload.methodName=\"jobservice.jobcompleted\""
  name                   = "bq_complete_sink"
  unique_writer_identity = true
  
  depends_on = [
      google_pubsub_topic.pubsub_external
  ]
}

resource "google_project_iam_binding" "project" {
  project = var.project_id
  role    = "roles/pubsub.publisher"

  members = [
    "${google_logging_project_sink.bq_complete_sink.writer_identity}",
  ]

  depends_on = [
    google_logging_project_sink.bq_complete_sink
  ]
}
/* End Log Sink */

/* GCS Files */
// Example Data
resource "google_storage_bucket_object" "example_data_csv" {
  name   = "input/data.csv.example"
  source = "../example/data.csv"
  bucket = var.bucket
  
  depends_on = [
       google_storage_bucket.gcs_bucket
  ]
}

resource "google_storage_bucket_object" "google_ads_yaml" {
  name   = "config/google-ads.yaml"
  
  content = <<-EOT
  developer_token: ${var.developer_token}
  client_id: ${var.client_id}
  client_secret: ${var.client_secret}
  refresh_token: ${var.refresh_token}
  login_customer_id: ${var.login_customer_id}
  use_proto_plus: True
  EOT
  
  bucket = var.bucket
  
  lifecycle {
    ignore_changes = all
  }
  
  depends_on = [
       google_storage_bucket.gcs_bucket
  ]
}
/* End GCS Files*/

/* Cloud Functions */
# Generates an archive of the source code compressed as a .zip file.
data "archive_file" "source" {
    type        = "zip"
    source_dir  = "../src"
    excludes    = setunion(fileset("${path.module}/../src", ".ipynb_checkpoints/**"),
                           fileset("${path.module}/../src", "__pycache__/**"))
    output_path = "/tmp/function.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "source_zip" {
    source       = data.archive_file.source.output_path
    content_type = "application/zip"

    # Append to the MD5 checksum of the files's content
    # to force the zip to be updated as soon as a change occurs
    name         = "code/src-${data.archive_file.source.output_md5}.zip"
    bucket       = google_storage_bucket.gcs_bucket.name

    # Dependencies are automatically inferred so these lines can be deleted
    depends_on   = [
        google_storage_bucket.gcs_bucket,
        data.archive_file.source
    ]
}

resource "google_cloudfunctions_function" "function_http" {
  for_each    = toset(["start", "send_single_event", "pingback_worker"])
  name        = each.key
  description = "Function"
  runtime     = "python37"

  #ingress_settings = "ALLOW_INTERNAL_AND_GCLB"
  available_memory_mb   = 1024
  source_archive_bucket = google_storage_bucket_object.source_zip.bucket
  source_archive_object = google_storage_bucket_object.source_zip.name
  trigger_http          = true
  entry_point           = each.key
  timeout               = 540
  
  depends_on = [
      google_project_service.cloudfunction,
      google_storage_bucket.gcs_bucket,
      data.archive_file.source,
      google_project_iam_member.appengine
  ]
}

resource "google_cloudfunctions_function" "function_pubsub" {
  for_each = {
    scheduler = google_pubsub_topic.pubsub_schedule.name,
    external_event_listener = google_pubsub_topic.pubsub_external.name,
    cron = google_pubsub_topic.pubsub_cronjob.name,
    email_cron = google_pubsub_topic.pubsub_email_cronjob.name,
  }
  name        = each.key
  description = "Function"
  runtime     = "python37"

  #ingress_settings = "ALLOW_INTERNAL_AND_GCLB"
  available_memory_mb   = 1024
  source_archive_bucket = google_storage_bucket_object.source_zip.bucket
  source_archive_object = google_storage_bucket_object.source_zip.name
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource = "projects/${var.project_id}/topics/${each.value}"
  }
  entry_point           = each.key
  timeout               = 540
  
  depends_on = [
      google_project_service.cloudfunction,
      google_storage_bucket.gcs_bucket,
      data.archive_file.source,
      google_project_iam_member.appengine
  ]
}
/* End Cloud Functions */

/* Cronjobs */
resource "google_cloud_scheduler_job" "cronjob" {
  name        = "bare-metal-cronjob"
  description = "Cron job to upload conversion data"
  schedule    = "*/10 * * * *"
  time_zone   = var.time_zone

  pubsub_target {
    # topic.id is the topic's full resource name.
    topic_name = google_pubsub_topic.pubsub_cronjob.id
    data       = base64encode("{}")
  }
  
  depends_on = [
      google_project_service.cloudscheduler
  ]
}

resource "google_cloud_scheduler_job" "email_cronjob" {
  name        = "bare-metal-email-cronjob"
  description = "Cron job to send summary"
  schedule    = "15 8 * * *"
  time_zone   = var.time_zone

  pubsub_target {
    # topic.id is the topic's full resource name.
    topic_name = google_pubsub_topic.pubsub_email_cronjob.id
    data       = base64encode("{}")
  }
  
  depends_on = [
      google_project_service.cloudscheduler
  ]
}
/* End Cronjobs */