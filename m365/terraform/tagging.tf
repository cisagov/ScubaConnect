data "azurerm_policy_definition_built_in" "tagging_policy" {
  display_name = "Add a tag to resources"
}

# Tagging policy for all resources in the main resource group
resource "azurerm_resource_group_policy_assignment" "tagging_assignments" {
  for_each             = var.tags
  name                 = "add-tags-${azurerm_resource_group.rg.name}"
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