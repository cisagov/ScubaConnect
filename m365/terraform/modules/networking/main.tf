# Network Security Group used by the VNet, allowing only 443 outbound
# Further destination restrictions may be imposed by Azure Firewall
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.resource_prefix}-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = [80, 443]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Deny-Outbound"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# VNet which hosts the ScubaGear container
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.resource_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet.address_space]

  lifecycle {
    ignore_changes = [tags]
  }
}

# Subnet which hosts the ScubaGear container, configured for Azure Container Instances
resource "azurerm_subnet" "aci-subnet" {
  name                 = "${var.resource_prefix}-aci-subnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = var.resource_group_name
  address_prefixes     = [var.vnet.aci_subnet]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "aci-del"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Associate the NSG with the VNet
resource "azurerm_subnet_network_security_group_association" "apply_nsg" {
  subnet_id                 = azurerm_subnet.aci-subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

