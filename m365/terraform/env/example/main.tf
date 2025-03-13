module "scuba_connect" {
  source                       = "../.."
  app_name                     = var.app_name
  app_multi_tenant             = var.app_multi_tenant
  image_path                   = var.image_path
  contact_emails               = var.contact_emails
  resource_group_name          = var.resource_group_name
  serial_number                = var.serial_number
  location                     = var.location
  schedule_interval            = var.schedule_interval
  tenants_dir_path             = var.tenants_dir_path
  vnet                         = var.vnet
  container_image              = var.container_image
  container_registry           = var.container_registry
  input_storage_container_url  = var.input_storage_container_url
  output_storage_container_url = var.output_storage_container_url
}

