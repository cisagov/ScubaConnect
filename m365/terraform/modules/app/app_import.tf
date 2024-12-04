data "azuread_application" "app" {
  count        = var.create_app ? 0 : 1
  display_name = var.app_name
}

data "azuread_service_principal" "app" {
  count        = var.create_app ? 0 : 1
  display_name = var.app_name
}