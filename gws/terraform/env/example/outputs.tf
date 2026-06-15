output "scuba_runner_svc_acct_id" {
  description = "ID of the service account used for authentication. Other projects will need to add using domain-wide delegation."
  value       = module.scuba_runner.scuba_runner_service_account.unique_id
}

output "scuba_runner_svc_acct_email" {
  description = "Email of the service account used for running ScubaGoggles. May be used for granting permissions to write to a pre-existing bucket"
  value       = module.scuba_runner.scuba_runner_service_account.email
}

output "output_storage_bucket" {
  description = "Bucket name where results are written to"
  value       = module.scuba_runner.output_storage_bucket
}

output "input_storage_bucket" {
  description = "Bucket name where config files are read from"
  value       = module.scuba_runner.input_storage_bucket
}

output "oauth_scopes" {
  description = "The OAuth scopes needed when adding for domain-wide delegation"
  # should match scubagoggles
  value = join(",",
    [
      "https://www.googleapis.com/auth/admin.reports.audit.readonly",
      "https://www.googleapis.com/auth/admin.directory.domain.readonly",
      "https://www.googleapis.com/auth/admin.directory.orgunit.readonly",
      "https://www.googleapis.com/auth/admin.directory.user.readonly",
      "https://www.googleapis.com/auth/admin.directory.group.readonly",
      "https://www.googleapis.com/auth/admin.directory.customer.readonly",
      "https://www.googleapis.com/auth/apps.groups.settings",
      "https://www.googleapis.com/auth/cloud-identity.policies.readonly"
    ]
  )
}
