data "azuread_application_published_app_ids" "well_known" {}

data "azuread_service_principal" "msgraph" {
  client_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph
}
data "azuread_service_principal" "o365exchange" {
  client_id = data.azuread_application_published_app_ids.well_known.result.Office365ExchangeOnline
}
data "azuread_service_principal" "sharepoint" {
  client_id = data.azuread_application_published_app_ids.well_known.result.Office365SharePointOnline
}

resource "azuread_application" "app" {
  count            = var.create_app ? 1 : 0
  display_name     = var.app_name
  logo_image       = filebase64(var.image_path)
  sign_in_audience = "AzureADMultipleOrgs"
  web {
    redirect_uris = ["https://portal.azure.com/#view/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade/~/AppAppsPreview"]
  }


  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.MicrosoftGraph

    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["Application.Read.All"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["Directory.Read.All"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["Domain.Read.All"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["GroupMember.Read.All"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["Organization.Read.All"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["Policy.Read.All"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["RoleManagement.Read.Directory"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["User.Read.All"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["PrivilegedEligibilitySchedule.Read.AzureADGroup"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["PrivilegedAccess.Read.AzureADGroup"]
      type = "Role"
    }
    resource_access {
      id   = data.azuread_service_principal.msgraph.app_role_ids["RoleManagementPolicy.Read.AzureADGroup"]
      type = "Role"
    }
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.Office365ExchangeOnline

    resource_access {
      id   = data.azuread_service_principal.o365exchange.app_role_ids["Exchange.ManageAsApp"]
      type = "Role"
    }
  }

  required_resource_access {
    resource_app_id = data.azuread_application_published_app_ids.well_known.result.Office365SharePointOnline

    resource_access {
      id   = data.azuread_service_principal.sharepoint.app_role_ids["Sites.FullControl.All"]
      type = "Role"
    }
  }
}

resource "azuread_service_principal" "app" {
  count     = var.create_app ? 1 : 0
  client_id = azuread_application.app[0].client_id
}