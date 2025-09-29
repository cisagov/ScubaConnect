# Azure Resource Group that contains most resources
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}-${var.serial_number}"
  location = var.location

  lifecycle {
    ignore_changes = [tags]
  }
}

data "azuread_client_config" "current" {}
data "azurerm_client_config" "current" {}

locals {
  name = var.prefix_override != null ? var.prefix_override : replace(lower(var.app_name), " ", "-")
}

resource "azurerm_log_analytics_workspace" "monitor_law" {
  name                = "${local.name}-monitor-loganalytics"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 90

  lifecycle {
    ignore_changes = [tags]
  }
  depends_on = [azurerm_resource_group_policy_assignment.tagging_assignments]
}

module "networking" {
  count               = var.vnet == null ? 0 : 1
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  resource_prefix     = local.name
  firewall            = var.firewall
  vnet                = var.vnet
  depends_on          = [azurerm_resource_group_policy_assignment.tagging_assignments]
}

# Creates the app registration, or reads an existing one, which is used by the ScubaGear container
module "app" {
  source              = "./modules/app"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  kv_prefix           = "${local.name}-${var.serial_number}"
  app_name            = var.app_name
  image_path          = var.image_path
  create_app          = var.create_app
  contact_emails      = var.contact_emails
  allowed_access_ips  = try(var.vnet.allowed_access_ip_list, null)
  aci_subnet_id       = try(module.networking[0].aci_subnet_id, null)
  app_multi_tenant    = var.app_multi_tenant
  depends_on          = [azurerm_resource_group_policy_assignment.tagging_assignments]
}

module "container" {
  source                       = "./modules/container"
  resource_prefix              = local.name
  resource_group               = azurerm_resource_group.rg
  container_registry           = var.container_registry
  container_image              = var.container_image
  application_client_id        = module.app.client_id
  application_object_id        = module.app.sp_object_id
  allowed_access_ips           = try(var.vnet.allowed_access_ip_list, null)
  subnet_ids                   = var.vnet == null ? null : [module.networking[0].aci_subnet_id]
  schedule_interval            = var.schedule_interval
  output_storage_container_url = var.output_storage_container_url
  output_storage_container_sas = var.output_storage_container_sas
  output_all_files             = var.output_all_files
  input_storage_container_url  = var.input_storage_container_url
  contact_emails               = var.contact_emails
  log_analytics_workspace      = azurerm_log_analytics_workspace.monitor_law
  container_memory_gb          = var.container_memory_gb
  cert_info                    = module.app.cert_info
  depends_on                   = [azurerm_resource_group_policy_assignment.tagging_assignments]
  secondary_app_info           = var.secondary_app_info
}
