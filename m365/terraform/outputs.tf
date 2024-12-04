output "app_id" {
  description = "APP ID of the application. This should be passed to the install script"
  value       = module.app.client_id
}

output "output_storage_container_id" {
  description = "ID of the output storage account results are written to"
  value       = module.container.output_storage_container_id
}

output "sp_object_id" {
  description = "Object ID for the application's Service Principal. This can be used to given additional permissions for writing to custom output locations"
  value       = module.app.sp_object_id
}