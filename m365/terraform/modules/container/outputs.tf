output "output_storage_container_urls" {
  description = "URLs of the output storage accounts results are written to"
  value       = local.output_storage_container_urls
}

output "input_storage_container_url" {
  description = "URL of the input storage account configs are read from"
  value       = local.input_storage_container_url
}
