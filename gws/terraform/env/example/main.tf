data "google_client_config" "this" {}

module "scuba_runner" {
  source               = "../../modules/scuba_runner"
  contact_emails       = var.contact_emails
  container_image      = var.container_image
  container_memory_gb  = var.container_memory_gb
  output_all_files     = var.output_all_files
  cron_schedule        = var.cron_schedule
  input_bucket         = var.input_bucket
  output_bucket        = var.output_bucket
  tenants_dir_path     = var.tenants_dir_path
}

