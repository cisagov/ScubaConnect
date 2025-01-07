resource "azurerm_monitor_action_group" "action_group" {
  name                = "${var.resource_prefix} Container Alerts"
  resource_group_name = var.resource_group.name
  short_name          = substr(var.resource_prefix, 0, 12)
  email_receiver {
    name          = "email"
    email_address = var.contact_email
  }

}

resource "azurerm_log_analytics_saved_search" "last_run_search" {
  name                       = "lastRunSearch"
  log_analytics_workspace_id = var.log_analytics_workspace.id

  category     = "${var.resource_prefix} Container"
  display_name = "${var.resource_prefix} Last Run Output"
  query        = <<-QUERY
    let e = toscalar(ContainerEvent_CL | where Message contains "pulling image" | summarize max(TimeGenerated)); 
    union ContainerEvent_CL, ContainerInstanceLog_CL
    | where TimeGenerated > e
    | project TimeGenerated, ContainerGroup_s, Type, Message
    | order by TimeGenerated asc
    QUERY
}

resource "azurerm_log_analytics_saved_search" "container_search" {
  name                       = "containerSearch"
  log_analytics_workspace_id = var.log_analytics_workspace.id

  category     = "${var.resource_prefix} Container"
  display_name = "${var.resource_prefix} Container Logs (7d)"
  query        = <<-QUERY
    union ContainerEvent_CL, ContainerInstanceLog_CL
    | where TimeGenerated > ago(7d)
    | order by TimeGenerated
    QUERY
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "exit_alert" {
  name                = "exit-code-alert"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  evaluation_frequency = "PT15M"
  window_duration      = "PT15M"
  scopes               = [var.log_analytics_workspace.id]
  severity             = 2
  criteria {
    query                   = <<-QUERY
        ContainerEvent_CL
        | where Message contains "Terminating with exit code 1"
      QUERY
    time_aggregation_method = "Count"
    threshold               = 1
    operator                = "GreaterThanOrEqual"
  }

  description  = "Alerts when ${var.resource_prefix} container has non-zero exit code."
  display_name = "${var.resource_prefix} Container Exit Code Alert"

  action {
    action_groups = [azurerm_monitor_action_group.action_group.id]
  }
  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "law_access" {
  scope                = var.log_analytics_workspace.id
  role_definition_name = "Reader"
  principal_id         = azurerm_monitor_scheduled_query_rules_alert_v2.exit_alert.identity[0].principal_id
}