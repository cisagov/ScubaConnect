# Plan-only tests; no Google credentials or cloud resources required.
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

run "managed_output" {
  command = plan
  assert {
    condition     = length(output.output_storage_buckets) == 1
    error_message = "Default managed output must remain supported."
  }
}

run "external_output" {
  command = plan
  variables {
    create_output_bucket = false
    extra_output_buckets = ["external-reports"]
  }
  assert {
    condition     = tolist(output.output_storage_buckets) == tolist(["external-reports"])
    error_message = "External-only output must remain supported."
  }
}

run "managed_and_external_output" {
  command = plan
  variables {
    extra_output_buckets = ["external-reports"]
  }
  assert {
    condition     = length(output.output_storage_buckets) == 2
    error_message = "Managed and external output must remain supported together."
  }
}

run "missing_output" {
  command = plan
  variables {
    create_output_bucket = false
  }
  expect_failures = [google_cloud_run_v2_job.scuba_runner]
}
