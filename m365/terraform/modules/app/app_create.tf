data "http" "tags" {
  url = "https://api.github.com/repos/cisagov/scubagear/tags"
}

data "http" "permissions_file" {
  # TODO: switch to tagged version once in mainline release
  # url = "https://raw.githubusercontent.com/cisagov/ScubaGear/refs/tags/${jsondecode(data.http.tags)[0]}/PowerShell/ScubaGear/Modules/Permissions/ScubaGearPermissions.json"
  url = "https://raw.githubusercontent.com/cisagov/ScubaGear/9294f435c1023fd548c56b49e9b3e9dda956f0c2/PowerShell/ScubaGear/Modules/Permissions/ScubaGearPermissions.json"
}

locals {
  json = jsondecode(data.http.permissions_file.response_body)
  init_mapping =  { for e in local.json: e["resourceAPIAppId"] => e["leastPermissions"]... if e["scubaGearProduct"] != ["scubatank"]}
  id_mapping = {for k, v in local.init_mapping: k => distinct(flatten(v)) if length(flatten(v)) > 0}
}

data "azuread_service_principal" "sps" {
  for_each = local.id_mapping
  client_id = each.key
}

resource "azuread_application" "app" {
  count            = var.create_app ? 1 : 0
  display_name     = var.app_name
  logo_image       = filebase64(var.image_path)
  sign_in_audience = var.app_multi_tenant ? "AzureADMultipleOrgs" : "AzureADMyOrg"
  web {
    redirect_uris = ["https://portal.azure.com/#view/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade/~/AppAppsPreview"]
  }

  dynamic "required_resource_access" {
    for_each = data.azuread_service_principal.sps
    content {
      resource_app_id = required_resource_access.value.client_id
      dynamic "resource_access" {
        for_each = local.id_mapping[required_resource_access.value.client_id]
        content {
          id = required_resource_access.value.app_role_ids[resource_access.value]
          type = "Role"
        }
      }
    }
  }
}

resource "azuread_service_principal" "app" {
  count     = var.create_app ? 1 : 0
  client_id = azuread_application.app[0].client_id
}

output "test" {
  value = data.azuread_service_principal.sps["00000003-0000-0000-c000-000000000000"].app_role_ids
}