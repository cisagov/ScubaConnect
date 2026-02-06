locals {
  required_apis = [
    # Needed to run ScubaGoggles
    "admin.googleapis.com",
    "cloudidentity.googleapis.com",
    "groupssettings.googleapis.com",
    # Needed for GogglesConnect resources
    "artifactregistry.googleapis.com",
    "cloudscheduler.googleapis.com",
    "run.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com"
    # This list excludes APIs enabled by default: https://docs.cloud.google.com/service-usage/docs/enabled-service#default
  ]
}

resource "google_project_service" "service" {
  for_each           = toset(local.required_apis)
  project            = data.google_client_config.this.project
  service            = each.key
  disable_on_destroy = false
}
