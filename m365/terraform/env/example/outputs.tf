output "app_id" {
  description = "APP ID of the application. This should be passed to the install script"
  value       = module.scuba_connect.app_id
}

output "output_storage_container_url" {
  description = "URL of the output storage account results are written to"
  value       = module.scuba_connect.output_storage_container_url
}

output "input_storage_container_url" {
  description = "URL of the input storage account configs are read from"
  value       = module.scuba_connect.output_storage_container_url
}

output "sp_object_id" {
  description = "Object ID for the application's Service Principal. This can be used to given additional permissions for reading/writing to custom storage locations"
  value       = module.scuba_connect.sp_object_id
}