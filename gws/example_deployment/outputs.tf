output "scuba_runner_svc_acct_id" {
  description = "ID of the service account used for authentication. Other projects will need to add using domain-wide delegation."
  value       = module.scuba_connect.scuba_runner_service_account.unique_id
}

output "scuba_runner_svc_acct_email" {
  description = "Email of the service account used for running ScubaGoggles. Used for granting roles"
  value       = module.scuba_connect.scuba_runner_service_account.email
}

output "oauth_scopes" {
  description = "The OAuth scopes needed when adding for domain-wide delegation"
  value       = module.scuba_connect.oauth_scopes
}

output "output_storage_buckets" {
  description = "Bucket names where results are written to"
  value       = module.scuba_connect.output_storage_buckets
}

output "input_storage_bucket" {
  description = "Bucket name where config files are read from"
  value       = module.scuba_connect.input_storage_bucket
}
