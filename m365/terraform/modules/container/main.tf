data "azurerm_client_config" "current" {}

locals {
  is_us_gov    = contains(split(" ", var.resource_group.location), "USGov")
  aad_endpoint = local.is_us_gov ? "https://login.microsoftonline.us" : "https://login.microsoftonline.com"
}

resource "azurerm_user_assigned_identity" "container_mi" {
  location            = var.resource_group.location
  name                = "${var.resource_prefix}-container-mi"
  resource_group_name = var.resource_group.name
}


resource "azurerm_key_vault_access_policy" "mi_kv_access" {
  key_vault_id = var.cert_info.vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.container_mi.principal_id

  certificate_permissions = [
    "Get", "List"
  ]
  secret_permissions = [
    "Get"
  ]
}

# Azure Container Instances to run the ScubaGear container
# One group is automatically executed periodically, the other manually
# Note on ip_address/port: 
#   If using a vnet, `ip_address_type` must be "Private" rather than "None".
#   (If you set as "None" it applies, but the state will be "Private".)
#   If "Private", a port must be opened on the container. This is dictated by Azure's APIs
#   The open port is still within the vnet, so nothing is exposed externally
resource "azurerm_container_group" "aci" {
  for_each            = toset(["scheduled", "adhoc"])
  name                = "${var.resource_prefix}-${each.key}-container"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  ip_address_type     = var.subnet_ids == null ? "None" : "Private"
  subnet_ids          = var.subnet_ids
  os_type             = "Windows"
  restart_policy      = "Never"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.container_mi.id]
  }

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
    cpu    = "1"
    memory = var.container_memory_gb
    environment_variables = {
      "RUN_TYPE"        = each.key
      "TENANT_ID"       = data.azurerm_client_config.current.tenant_id
      "APP_ID"          = var.application_client_id
      "REPORT_OUTPUT"   = local.output_storage_container_url
      "TENANT_INPUT"    = local.input_storage_container_url
      "IS_VNET"         = var.subnet_ids != null
      "IS_GOV"          = local.is_us_gov
      "VAULT_NAME"      = var.cert_info.vault_name
      "CERT_NAME"       = var.cert_info.cert_name
      "DEBUG_LOG"       = "false"
      "MI_PRINCIPAL_ID" = azurerm_user_assigned_identity.container_mi.principal_id
    }
    dynamic "ports" {
      for_each = var.subnet_ids == null ? [] : [1]
      content {
        port     = 443
        protocol = "TCP"
      }
    }
  }

  lifecycle {
    ignore_changes = [tags]
  }

  depends_on = [azurerm_key_vault_access_policy.mi_kv_access]
}



