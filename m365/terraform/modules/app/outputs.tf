output "id" {
  description = "The terraform resource ID of the created/imported app"
  value       = var.create_app ? azuread_application.app[0].id : data.azuread_application.app[0].id
}

output "client_id" {
  description = "The Client ID of the created/imported app"
  value       = var.create_app ? azuread_application.app[0].client_id : data.azuread_application.app[0].client_id
}

output "sp_object_id" {
  description = "The service principal object ID for the created/imported app. Use this for granting additional permissions to the SP"
  value       = var.create_app ? azuread_service_principal.app[0].object_id : data.azuread_service_principal.app[0].object_id
}

output "cert_info" {
  description = "Info for cert and its associated keyvault"
  value     = {
    vault_id = azurerm_key_vault.vault.id
    vault_name = azurerm_key_vault.vault.name
    cert_name = azurerm_key_vault_certificate.cert.name
  }
}