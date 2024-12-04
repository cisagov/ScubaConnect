variable "app_name" {
  type        = string
  description = "App name. Displayed in Azure console on installed tenants"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix to use in resource names"
}

variable "resource_group_name" {
  type        = string
  description = "Name of resource group resources are in"
}

variable "location" {
  type        = string
  description = "Location for resource"
}

variable "contact_email" {
  description = "Email to notify before certificate expiry"
  type        = string
}

variable "image_path" {
  type        = string
  description = "Path to image used for app logo. Displayed in Azure console on installed tenants. Only needed when create_app=true"
}

variable "create_app" {
  type        = bool
  description = "If true, the app will be created. If false, the app will be imported"
}

variable "allowed_access_ips" {
  type        = list(string)
  description = "List of IP addresses/subnets in CIDR format that should be able to access keyvault"
}
