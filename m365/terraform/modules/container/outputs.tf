output "output_storage_container_id" {
  description = "ID of the output storage account results are written to"
  value       = var.output_storage_container_id == null ? azurerm_storage_container.output[0].id : var.output_storage_container_id
}

output "input_storage_container_id" {
  description = "ID of the input storage account configs are read from"
  value       = var.input_storage_container_id == null ? azurerm_storage_container.input[0].id : var.input_storage_container_id
}