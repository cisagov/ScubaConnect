# These plan-only tests use mocked providers and require no cloud credentials.
mock_provider "google" {
  mock_data "google_client_config" {
    defaults = {
      project = "test-project"
      region  = "us-central1"
    }
  }
}

mock_provider "random" {}

variables {
  cron_schedule    = "0 0 * * *"
  contact_emails   = []
  tenants_dir_path = "../../env/example/tenants"
}

run "existing_input_managed_output" {
  command = plan

  variables {
    input_bucket = "existing-input"
  }

  assert {
    condition = (
      length(google_storage_bucket.input_bucket) == 0 &&
      length(google_storage_bucket_object.type_folder) == 0 &&
      length(google_storage_bucket_object.tenants) == 0 &&
      length(google_storage_bucket_iam_member.scuba_runner_input_storage_perms) == 0
    )
    error_message = "An existing input bucket must not create or manage input resources."
  }

  assert {
    condition     = output.input_storage_bucket == "existing-input" && length(google_storage_bucket.output_bucket) == 1
    error_message = "The provided input bucket and managed output bucket must both be retained."
  }
}

run "existing_input_external_output" {
  command = plan

  variables {
    input_bucket         = "existing-input"
    create_output_bucket = false
    extra_output_buckets = ["external-output"]
  }

  assert {
    condition = (
      length(google_storage_bucket.input_bucket) == 0 &&
      length(google_storage_bucket.output_bucket) == 0 &&
      length(google_storage_bucket.log_bucket) == 0 &&
      length(google_storage_bucket_object.type_folder) == 0 &&
      length(google_storage_bucket_object.tenants) == 0
    )
    error_message = "External storage must not create buckets or input objects."
  }

  assert {
    condition     = output.input_storage_bucket == "existing-input" && tolist(output.output_storage_buckets) == tolist(["external-output"])
    error_message = "External storage names must be passed through unchanged."
  }
}

run "managed_input_managed_output" {
  command = plan

  assert {
    condition = (
      length(google_storage_bucket.input_bucket) == 1 &&
      toset(keys(google_storage_bucket_object.type_folder)) == toset(["adhoc", "scheduled"]) &&
      toset(keys(google_storage_bucket_object.tenants)) == toset(["adhoc/example.org.yaml", "scheduled/example.org.yaml"])
    )
    error_message = "Managed input storage must retain both folders and tenant uploads."
  }
}

run "managed_input_external_output" {
  command = plan

  variables {
    create_output_bucket = false
    extra_output_buckets = ["external-output"]
  }

  assert {
    condition = (
      length(google_storage_bucket.input_bucket) == 1 &&
      length(google_storage_bucket.output_bucket) == 0 &&
      length(google_storage_bucket.log_bucket) == 1 &&
      toset(keys(google_storage_bucket_object.type_folder)) == toset(["adhoc", "scheduled"])
    )
    error_message = "Managed input folders must not depend on output bucket creation."
  }
}
