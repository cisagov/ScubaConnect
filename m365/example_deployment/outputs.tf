output "app_id" {
  description = "The application client ID. Used when onboarding tenants with Install-GearConnect.ps1"
  value       = module.scuba_connect.app_id
}

output "sp_object_id" {
  description = "The service principal object ID. Used when configuring external storage permissions"
  value       = module.scuba_connect.sp_object_id
}

output "output_storage_container_urls" {
  description = "Container URLs where results are written to"
  value       = module.scuba_connect.output_storage_container_urls
}

output "input_storage_container_url" {
  description = "Container URL where config files are read from"
  value       = module.scuba_connect.input_storage_container_url
}
