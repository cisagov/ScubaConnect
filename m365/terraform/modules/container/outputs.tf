output "output_storage_container_url" {
  description = "URL of the output storage account results are written to"
  value       = local.output_storage_container_url
}

output "input_storage_container_url" {
  description = "URL of the input storage account configs are read from"
  value       = local.input_storage_container_url
}
