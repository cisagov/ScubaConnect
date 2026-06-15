output "scuba_runner_service_account" {
  value       = google_service_account.scuba_runner_service_account
  description = "Service account created for running ScubaGoggles against organizations"
}

output "output_storage_bucket" {
  description = "Bucket name where results are written to"
  value       = local.output_storage_bucket
}

output "input_storage_bucket" {
  description = "Bucket name where config files are read from"
  value       = local.input_storage_bucket
}