variable "resource_group_name" {
  type        = string
  description = "Name of resource group resources are in"
}

variable "location" {
  type        = string
  description = "Location for resource"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix to use in resource names"
}

variable "firewall" {
  default = null
  type = object({
    resource_group = string
    vnet           = string
    pip            = string
    name           = string
  })
  description = "Configuration for an Azure Firewall; if not null, traffic will be routed through this firewall"
}

variable "vnet" {
  type = object({
    address_space          = string
    aci_subnet             = string
    allowed_access_ip_list = list(string)
  })
  description = "Configuration for the vnet, including the address space, ACI subnet, and a list of allowed IP ranges. All strings in CIDR format"
}