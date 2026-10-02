output "scuba_runner_service_account" {
  value       = google_service_account.scuba_runner_service_account
  description = "Service account created for running ScubaGoggles against organizations"
}

output "output_storage_buckets" {
  description = "Bucket names where results are written to"
  value       = local.output_storage_buckets
}

output "input_storage_bucket" {
  description = "Bucket name where config files are read from"
  value       = local.input_storage_bucket
}

output "oauth_scopes" {
  description = "The OAuth scopes needed when adding for domain-wide delegation"
  # should match scubagoggles
  value = join(",",
    [
      "https://www.googleapis.com/auth/admin.reports.audit.readonly",
      "https://www.googleapis.com/auth/admin.directory.domain.readonly",
      "https://www.googleapis.com/auth/admin.directory.group.readonly",
      "https://www.googleapis.com/auth/admin.directory.orgunit.readonly",
      "https://www.googleapis.com/auth/admin.directory.user.readonly",
      "https://www.googleapis.com/auth/admin.directory.rolemanagement.readonly",
      "https://www.googleapis.com/auth/admin.directory.customer.readonly",
      "https://www.googleapis.com/auth/cloud-identity.policies.readonly",
      "https://www.googleapis.com/auth/cloud-identity.inboundsso.readonly"
    ]
  )
}