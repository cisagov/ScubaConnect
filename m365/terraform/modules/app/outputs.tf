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

output "certificate_pfx_b64" {
  sensitive = true
  value     = data.azurerm_key_vault_secret.pfx_b64.value
}