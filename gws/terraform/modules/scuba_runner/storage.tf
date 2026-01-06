locals {
  container_types = ["scheduled", "adhoc"]
  log_bucket_name = "gogglesconnect-storage-logs-${data.google_client_config.this.project}"
}

# STORAGE LOG BUCKET

resource "google_storage_bucket" "log_bucket" {
  count         = var.input_bucket == null || var.output_bucket == null ? 1 : 0
  name          = local.log_bucket_name
  location      = data.google_client_config.this.region
  force_destroy = true # allows destroying bucket w/ objects. 
  versioning {
    enabled = true
  }
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 7
    }
    action {
      type = "Delete"
    }
  }

  logging {
    log_bucket = local.log_bucket_name
  }

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

# INPUT BUCKET

resource "google_storage_bucket" "input_bucket" {
  count         = var.input_bucket == null ? 1 : 0
  name          = "gogglesconnect-input-${data.google_client_config.this.project}"
  location      = data.google_client_config.this.region
  force_destroy = true # allows destroying bucket w/ objects. 
  versioning {
    enabled = true
  }
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 7
    }
    action {
      type = "Delete"
    }
  }

  logging {
    log_bucket = local.log_bucket_name
  }

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

resource "google_storage_bucket_iam_member" "scuba_runner_input_storage_perms" {
  count  = var.input_bucket == null ? 1 : 0
  bucket = google_storage_bucket.input_bucket[0].name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.scuba_runner_service_account.email}"
}

resource "google_storage_bucket_object" "type_folder" {
  for_each = toset(local.container_types)
  name     = "${each.key}/"
  content  = " " # content is ignored but should be non-empty
  bucket   = google_storage_bucket.input_bucket[0].name
}


# objects containing configuration for each tenant
resource "google_storage_bucket_object" "tenants" {
  for_each = var.input_bucket == null ? { for typeFile in setproduct(local.container_types, fileset(var.tenants_dir_path, "*")) : "${typeFile[0]}/${typeFile[1]}" => typeFile[1] } : {}
  name     = each.key
  source   = "${var.tenants_dir_path}/${each.value}"
  bucket   = google_storage_bucket.input_bucket[0].name
}

# OUTPUT BUCKET

resource "google_storage_bucket" "output_bucket" {
  count         = var.output_bucket == null ? 1 : 0
  name          = "gogglesconnect-output-${data.google_client_config.this.project}"
  location      = data.google_client_config.this.region
  force_destroy = true # allows destroying bucket w/ objects. 
  versioning {
    enabled = true
  }
  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 7
    }
    action {
      type = "Delete"
    }
  }

  logging {
    log_bucket = local.log_bucket_name
  }

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
}

resource "random_string" "unique_role_id" {
  length  = 8
  upper   = false
  special = false
}

# use random string to ensure unique since custom roles are soft-deleted:
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam_custom_role
resource "google_project_iam_custom_role" "custom_storage_role" {
  count       = var.output_bucket == null ? 1 : 0
  role_id     = "gogglesconnect_storage_write_role_${random_string.unique_role_id.result}"
  title       = "Custom Storage Write Role"
  description = "Role with minimal permissions for writing to storage bucket"
  permissions = ["storage.buckets.get", "storage.objects.create"]
}

resource "google_storage_bucket_iam_member" "scuba_runner_output_storage_perms" {
  count  = var.output_bucket == null ? 1 : 0
  bucket = google_storage_bucket.output_bucket[0].name
  role   = google_project_iam_custom_role.custom_storage_role[0].name
  member = "serviceAccount:${google_service_account.scuba_runner_service_account.email}"
}

locals {
  input_storage_bucket  = var.input_bucket == null ? google_storage_bucket.input_bucket[0].name : var.input_bucket
  output_storage_bucket = var.output_bucket == null ? google_storage_bucket.output_bucket[0].name : var.output_bucket
}