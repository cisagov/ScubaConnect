locals {
  aa_prefix    = "${var.resource_prefix}-runner-automation-"
  aa_unique_id = substr(replace(var.application_client_id, "-", ""), 0, 50 - length(local.aa_prefix))
}

# Automation Account for a script which periodically runs the ScubaGear container
resource "azurerm_automation_account" "runner_aa" {
  name                = "${local.aa_prefix}${local.aa_unique_id}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# Role which allows the script to start Azure Container Instances
resource "azurerm_role_definition" "start_container_role" {
  name  = "${var.resource_prefix}-start-aci-${var.application_client_id}"
  scope = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group.name}"

  permissions {
    actions = ["Microsoft.ContainerInstance/containerGroups/start/action"]
  }
}

# Assigns the role to the automation account
resource "azurerm_role_assignment" "aa_system_id" {
  scope              = var.resource_group.id
  role_definition_id = azurerm_role_definition.start_container_role.role_definition_resource_id
  principal_id       = azurerm_automation_account.runner_aa.identity[0].principal_id
}

data "local_file" "runner_runbook" {
  filename = "${path.module}/runner_runbook.ps1"
}

# Azure Runbook the script itself (see runner_runbook.ps1)
resource "azurerm_automation_runbook" "runner_book" {
  name                    = "${var.resource_prefix}-runner-runbook"
  location                = var.resource_group.location
  resource_group_name     = var.resource_group.name
  automation_account_name = azurerm_automation_account.runner_aa.name
  log_verbose             = "true"
  log_progress            = "true"
  description             = "Runbook for starting scheduled ${var.resource_prefix} container instance"
  runbook_type            = "PowerShell72"

  content = data.local_file.runner_runbook.content

  lifecycle {
    ignore_changes = [tags]
  }
}

# Simple schedule for the runbook
resource "azurerm_automation_schedule" "runner_schedule" {
  name                    = "${var.resource_prefix}-runner-schedule"
  resource_group_name     = var.resource_group.name
  automation_account_name = azurerm_automation_account.runner_aa.name
  frequency               = var.schedule_interval
  interval                = 1
  description             = "Schedule to run ${var.resource_prefix} container instance"
}

# Assigns the schedule to the runbook
resource "azurerm_automation_job_schedule" "runner_job_schedule" {
  resource_group_name     = var.resource_group.name
  automation_account_name = azurerm_automation_account.runner_aa.name
  schedule_name           = azurerm_automation_schedule.runner_schedule.name
  runbook_name            = azurerm_automation_runbook.runner_book.name
  parameters = {
    # must be all lowercase here: https://github.com/Azure/azure-sdk-for-go/issues/4780
    "resourcegroupname"     = var.resource_group.name
    "containerinstancename" = azurerm_container_group.aci["scheduled"].name
    "environment"           = local.is_us_gov ? "AzureUSGovernment" : "AzureCloud"
  }
}