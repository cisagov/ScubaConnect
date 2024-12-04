output "app_id" {
  description = "APP ID of the application. This should be passed to the install script"
  value       = module.scuba_connect.app_id
}

output "output_storage_container_id" {
  description = "ID of the output storage account results are written to"
  value       = module.scuba_connect.output_storage_container_id
}

output "sp_object_id" {
  description = "Object ID for the application's Service Principal"
  value       = module.scuba_connect.sp_object_id
}