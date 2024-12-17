module "scuba_connect" {
  source                           = "../.."
  app_name                         = var.app_name
  app_multi_tenant                 = var.app_multi_tenant
  image_path                       = var.image_path
  contact_email                    = var.contact_email
  resource_group_name              = var.resource_group_name
  serial_number                    = var.serial_number
  location                         = var.location
  schedule_interval                = var.schedule_interval
  tenants_dir_path                 = var.tenants_dir_path
  vnet                             = var.vnet
  container_image                  = var.container_image
  container_registry               = var.container_registry
  input_storage_container_id       = var.input_storage_container_id
  output_storage_container_id      = var.output_storage_container_id
  certificate_rotation_period_days = var.certificate_rotation_period_days
}

