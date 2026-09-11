module "scuba_connect" {
  # TODO: pin to latest release tag from https://github.com/cisagov/ScubaConnect/releases
  source = "github.com/cisagov/ScubaConnect.git//m365/terraform?ref=vX.Y.Z"

  # TODO: set email addresses to notify on failures and cert expiry
  contact_emails = ["TODO@example.com"]

  # TODO: set resource group name (will be created)
  resource_group_name = "TODO-myresourcegroup"

  # Optional: local tenant config directory (see README onboarding section)
  tenants_dir_path = "./tenants"

  # Optional overrides — see README "Terraform Variables" section for all options & defaults:
  # location            = "East US"
  # schedule_interval   = "Week"
  # app_multi_tenant    = false
  # output_all_files    = false
}
