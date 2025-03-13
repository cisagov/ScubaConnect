data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

locals {
  kv_prefix    = "${var.resource_prefix}-kv-"
  kv_unique_id = substr(replace((var.create_app ? azuread_application.app[0].client_id : data.azuread_application.app[0].client_id), "-", ""), 0, 24 - length(local.kv_prefix))
}

# Azure Key Vault to hold an app registration certificate
resource "azurerm_key_vault" "vault" {
  name                            = "${local.kv_prefix}${local.kv_unique_id}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days      = 7
  purge_protection_enabled        = true
  sku_name                        = "standard"
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  enable_rbac_authorization       = false

  dynamic "network_acls" {
    for_each = var.allowed_access_ips == null && var.aci_subnet_id == null ? [] : [1]
    content {
      default_action             = "Deny"
      ip_rules                   = var.allowed_access_ips
      virtual_network_subnet_ids = var.aci_subnet_id == null ? [] : [var.aci_subnet_id]
      bypass                     = "None"
    }
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_key_vault_access_policy" "kv_access" {
  key_vault_id = azurerm_key_vault.vault.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_client_config.current.object_id

  certificate_permissions = [
    "Create",
    "Delete",
    "Recover",
    "Get",
    "GetIssuers",
    "Import",
    "List",
    "ListIssuers",
    "ManageContacts",
    "Purge",
    "Update",
  ]

  secret_permissions = [
    "Delete",
    "Get",
    "List",
    "Purge",
    "Recover",
    "Set",
  ]
}

resource "azurerm_key_vault_certificate_contacts" "contacts" {
  key_vault_id = azurerm_key_vault.vault.id

  dynamic "contact" {
    for_each = var.contact_emails
    content {
      email = contact.value
    }
  }

  depends_on = [azurerm_key_vault_access_policy.kv_access]
}

# note this requires terraform to be run regularly
resource "time_rotating" "cert_rotation" {
  rotation_days = 9 * 30
}

# Generate the app registration certificate
resource "azurerm_key_vault_certificate" "cert" {
  # Name change forces recreating certificate
  name         = "${var.resource_prefix}-app-cert-${formatdate("YYYY-MM-DD", time_rotating.cert_rotation.rfc3339)}"
  key_vault_id = azurerm_key_vault.vault.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "EmailContacts"
      }

      trigger {
        days_before_expiry = 60
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      # client and server authentication
      extended_key_usage = ["1.3.6.1.5.5.7.3.1", "1.3.6.1.5.5.7.3.2"]

      key_usage = [
        "digitalSignature",
        "keyEncipherment",
      ]

      subject            = "CN=${var.app_name}"
      validity_in_months = 12
    }
  }

  depends_on = [azurerm_key_vault_access_policy.kv_access]
}

// note: if terraform isn't creating the app, a user must manually add the cert to the app
resource "azuread_application_certificate" "app_cert" {
  count          = var.create_app ? 1 : 0
  application_id = var.create_app ? azuread_application.app[0].id : data.azuread_application.app[0].id
  type           = "AsymmetricX509Cert"
  encoding       = "hex"
  value          = azurerm_key_vault_certificate.cert.certificate_data
  end_date       = azurerm_key_vault_certificate.cert.certificate_attribute[0].expires
  start_date     = azurerm_key_vault_certificate.cert.certificate_attribute[0].not_before
}

data "azurerm_key_vault_certificate_data" "scuba_cert_data" {
  name         = azurerm_key_vault_certificate.cert.name
  key_vault_id = azurerm_key_vault.vault.id
}

# Write the cert to a file if it needs to be manually added to the app
resource "local_file" "scuba_pem_file" {
  content  = data.azurerm_key_vault_certificate_data.scuba_cert_data.pem
  filename = "${path.cwd}/${var.app_name}.pem"
}

