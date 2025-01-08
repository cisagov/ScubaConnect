# Azure Resource Group that contains most resources
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}-${var.serial_number}"
  location = var.location
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
}

# Creates the app registration, or reads an existing one, which is used by the ScubaGear container
module "app" {
  source                           = "./modules/app"
  resource_group_name              = azurerm_resource_group.rg.name
  location                         = var.location
  resource_prefix                  = local.name
  app_name                         = var.app_name
  image_path                       = var.image_path
  create_app                       = var.create_app
  contact_emails                   = var.contact_emails
  allowed_access_ips               = var.vnet.allowed_access_ip_list
  certificate_rotation_period_days = var.certificate_rotation_period_days
  app_multi_tenant                 = var.app_multi_tenant
}

module "networking" {
  source              = "./modules/networking"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  resource_prefix     = local.name
  firewall            = var.firewall
  vnet                = var.vnet
}


module "container" {
  source                      = "./modules/container"
  resource_prefix             = local.name
  resource_group              = azurerm_resource_group.rg
  container_registry          = var.container_registry
  container_image             = var.container_image
  application_client_id       = module.app.client_id
  application_object_id       = module.app.sp_object_id
  application_pfx_b64         = module.app.certificate_pfx_b64
  allowed_access_ips          = var.vnet.allowed_access_ip_list
  subnet_ids                  = [module.networking.aci_subnet_id]
  schedule_interval           = var.schedule_interval
  output_storage_container_id = var.output_storage_container_id
  input_storage_container_id  = var.input_storage_container_id
  contact_emails              = var.contact_emails
  log_analytics_workspace     = azurerm_log_analytics_workspace.monitor_law
}
