data "azurerm_client_config" "current" {}

locals {
  is_us_gov    = contains(split(" ", var.resource_group.location), "USGov")
  aad_endpoint = local.is_us_gov ? "https://login.microsoftonline.us" : "https://login.microsoftonline.com"
}

# Azure Container Instances to run the ScubaGear container
# One group is automatically executed periodically, the other manually
resource "azurerm_container_group" "aci" {
  for_each            = toset(["scheduled", "adhoc"])
  name                = "${var.resource_prefix}-${each.key}-container"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  ip_address_type     = "None"
  subnet_ids          = var.subnet_ids
  os_type             = "Windows"
  restart_policy      = "Never"

  image_registry_credential {
    server   = var.container_registry.server
    username = var.container_registry.username
    password = var.container_registry.password
  }

  diagnostics {
    log_analytics {
      workspace_id  = var.log_analytics_workspace.workspace_id
      workspace_key = var.log_analytics_workspace.primary_shared_key
    }
  }

  container {
    name   = "${var.resource_prefix}-container"
    image  = var.container_image
    cpu    = "0.5"
    memory = "3"
    environment_variables = {
      "RUN_TYPE"                         = each.key
      "TENANT_ID"                        = data.azurerm_client_config.current.tenant_id
      "APP_ID"                           = var.application_client_id
      "REPORT_OUTPUT"                    = var.output_storage_container_id == null ? azurerm_storage_container.output[0].id : var.output_storage_container_id
      "TENANT_INPUT"                     = var.input_storage_container_id == null ? azurerm_storage_container.input[0].id : var.input_storage_container_id
      "AZCOPY_ACTIVE_DIRECTORY_ENDPOINT" = local.aad_endpoint
    }
    secure_environment_variables = {
      "PFX_B64" = var.application_pfx_b64
    }
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
