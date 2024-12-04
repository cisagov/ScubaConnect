data "azurerm_public_ip" "firewall_ip" {
  count               = var.firewall != null ? 1 : 0
  name                = var.firewall.pip
  resource_group_name = var.firewall.resource_group
}

data "azurerm_firewall" "firewall" {
  count               = var.firewall != null ? 1 : 0
  name                = var.firewall.name
  resource_group_name = var.firewall.resource_group
}

resource "azurerm_route_table" "route_table" {
  count               = var.firewall != null ? 1 : 0
  name                = "${var.resource_prefix}-rt"
  location            = var.location
  resource_group_name = var.resource_group_name

  lifecycle {
    ignore_changes = [tags]
  }

  route {
    name                   = "${var.resource_prefix}-quad0"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = data.azurerm_firewall.firewall[0].ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "apply_rt" {
  count          = var.firewall != null ? 1 : 0
  subnet_id      = azurerm_subnet.aci-subnet.id
  route_table_id = azurerm_route_table.route_table[0].id
}

data "azurerm_virtual_network" "firewall_vnet" {
  count               = var.firewall != null ? 1 : 0
  name                = var.firewall.vnet
  resource_group_name = var.firewall.resource_group
}

resource "azurerm_virtual_network_peering" "firewall_peering" {
  count                     = var.firewall != null ? 1 : 0
  name                      = "peer-scuba-to-firewall"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.vnet.name
  remote_virtual_network_id = data.azurerm_virtual_network.firewall_vnet[0].id
}