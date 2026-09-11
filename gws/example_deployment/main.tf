module "scuba_runner" {
  # TODO: pin to latest release tag from https://github.com/cisagov/ScubaConnect/releases
  source = "github.com/cisagov/ScubaConnect.git//gws/terraform?ref=vX.Y.Z"
  # TODO: set email addresses to notify on failures
  contact_emails = ["TODO@example.com"]  

  # Optional: local tenant config directory (see README onboarding section)
  tenants_dir_path = "./tenants"
  # Optional overrides — see README "Terraform Variables" section for all options & defaults:
  # cron_schedule        = "0 0 * * 0"  # Weekly Sunday midnight
  # output_all_files     = false
}
