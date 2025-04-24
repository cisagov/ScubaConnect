data "azurerm_policy_definition_built_in" "tagging_policy" {
  display_name = "Add a tag to resources"
}

# Tagging policy for all resources in the main resource group
resource "azurerm_resource_group_policy_assignment" "tagging_assignments" {
  for_each             = var.tags
  name                 = "add-tags-${azurerm_resource_group.rg.name}-${each.key}"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_definition_id = data.azurerm_policy_definition_built_in.tagging_policy.id

  parameters = jsonencode({
    tagName  = { value = each.key },
    tagValue = { value = each.value }
  })

  identity {
    type = "SystemAssigned"
  }
  location = var.location
}

resource "azurerm_role_assignment" "tag_contributor" {
  for_each = var.tags
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Tag Contributor"
  principal_id         = azurerm_resource_group_policy_assignment.tagging_assignments[each.key].identity[0].principal_id
}

resource "azurerm_resource_group_policy_remediation" "remediation" {
  for_each = var.tags
  name                 = "add-tags-policy-remediation-${each.key}"
  resource_group_id    = azurerm_resource_group.rg.id
  policy_assignment_id = azurerm_resource_group_policy_assignment.tagging_assignments[each.key].id
  resource_discovery_mode = "ReEvaluateCompliance"
  depends_on = [ azurerm_role_assignment.tag_contributor, module.app, module.container, module.networking ]
}