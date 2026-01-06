data "google_client_config" "this" {}

# SA

resource "google_service_account" "scuba_runner_service_account" {
  account_id  = "scuba-runner-service-acct"
  description = "Service account used by scuba-runner cloud run job. Added with domain-wide delegation to participating orgs"
}

resource "google_project_iam_member" "scuba_runner_log_write" {
  project = data.google_client_config.this.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.scuba_runner_service_account.email}"
}

resource "google_project_iam_member" "scuba_runner_scheduler_run" {
  project = data.google_client_config.this.project
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.scuba_runner_service_account.email}"
}

# allow creating token for self
resource "google_service_account_iam_member" "gws_sa_impersonate_role" {
  service_account_id = google_service_account.scuba_runner_service_account.id
  member             = "serviceAccount:${google_service_account.scuba_runner_service_account.email}"
  role               = "roles/iam.serviceAccountTokenCreator"
}

# ARTIFACT REPO REMOTE

# Note: this will only check for updates to a docker tag every 1h
resource "google_artifact_registry_repository" "ghcr_remote_repo" {
  project                = data.google_client_config.this.project
  location               = data.google_client_config.this.region
  repository_id          = "ghcr-remote-cache"
  format                 = "DOCKER"
  mode                   = "REMOTE_REPOSITORY"
  description            = "Remote repository for caching GHCR images"
  cleanup_policy_dry_run = false
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "7d"
    }
  }

  remote_repository_config {
    docker_repository {
      custom_repository {
        uri = "https://ghcr.io"
      }
    }
  }

  depends_on = [google_project_service.service]
}

# CLOUD RUN JOB

resource "google_cloud_run_v2_job" "scuba_runner" {
  name                = "gogglesconnect-runner"
  location            = data.google_client_config.this.region
  deletion_protection = false

  template {
    template {
      service_account = google_service_account.scuba_runner_service_account.email
      max_retries     = 0
      containers {
        image = "${data.google_client_config.this.region}-docker.pkg.dev/${data.google_client_config.this.project}/${google_artifact_registry_repository.ghcr_remote_repo.repository_id}/${var.container_image}"
        resources {
          limits = {
            cpu    = "1"
            memory = "${var.container_memory_gb}G"
          }
        }
        env {
          name  = "PROJECT"
          value = data.google_client_config.this.project
        }
        env {
          name  = "INPUT_BUCKET"
          value = var.input_bucket == null ? google_storage_bucket.input_bucket[0].name : var.input_bucket
        }
        env {
          name  = "OUTPUT_BUCKET"
          value = var.output_bucket == null ? google_storage_bucket.output_bucket[0].name : var.output_bucket
        }
        env {
          name  = "OUTPUT_ALL_FILES"
          value = var.output_all_files
        }
        env {
          name  = "RUN_TYPE"
          value = "adhoc" # cloud scheduler overrides this to scheduled
        }
      }
    }
  }

  depends_on = [google_project_service.service, google_artifact_registry_repository.ghcr_remote_repo]
}

# CLOUD SCHEDULER

resource "google_cloud_scheduler_job" "scuba_run_scheduler" {
  name        = "${google_cloud_run_v2_job.scuba_runner.name}-scheduler"
  description = "Trigger the ${google_cloud_run_v2_job.scuba_runner.name} job on schedule."
  schedule    = var.cron_schedule

  http_target {
    http_method = "POST"
    uri         = "https://${google_cloud_run_v2_job.scuba_runner.location}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${data.google_client_config.this.project}/jobs/${google_cloud_run_v2_job.scuba_runner.name}:run"
    body        = base64encode(jsonencode({ "overrides" : { "containerOverrides" : [{ "env" : [{ "name" : "RUN_TYPE", "value" : "scheduled" }] }] } }))
    oauth_token {
      service_account_email = google_service_account.scuba_runner_service_account.email
    }
  }
  depends_on = [google_project_service.service, google_project_iam_member.scuba_runner_scheduler_run]
}

# ALERTS

resource "google_monitoring_notification_channel" "email_alert" {
  for_each     = toset(var.contact_emails)
  display_name = "GogglesConnect Alert Notification Channel"
  type         = "email"
  labels = {
    email_address = each.key
  }
  force_delete = true
}

resource "google_monitoring_alert_policy" "log_alert_policy" {
  display_name          = "GogglesConnect Run Errors"
  notification_channels = [for alert in google_monitoring_notification_channel.email_alert : alert.name]
  severity              = "ERROR"
  combiner              = "OR"

  conditions {
    display_name = "Logged message with severity>=ERROR"
    # easiest way to build these options is to build an alert in console then select "view code" and translate json
    condition_matched_log {
      filter = "resource.labels.job_name=\"${google_cloud_run_v2_job.scuba_runner.name}\" AND severity>=\"ERROR\""
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "3600s"
    }
    auto_close = "604800s" # 7 days
  }
}
