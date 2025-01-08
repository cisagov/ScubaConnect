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

variable "contact_emails" {
  description = "Emails to notify before certificate expiry"
  type        = list(string)
}

variable "certificate_rotation_period_days" {
  type        = number
  description = "How many days between when the certificate key should be rotated. Note: rotation requires running terraform"
  default     = 30
  validation {
    condition     = var.certificate_rotation_period_days <= 60 && var.certificate_rotation_period_days >= 3
    error_message = "Rotation period must be between 3 and 60 days"
  }
}

variable "image_path" {
  type        = string
  description = "Path to image used for app logo. Displayed in Azure console on installed tenants. Only needed when create_app=true"
}

variable "create_app" {
  type        = bool
  description = "If true, the app will be created. If false, the app will be imported"
}

variable "app_multi_tenant" {
  type        = bool
  default     = false
  description = "If true, the app will be able to be installed in multiple tenants. By default, it is only available in this tenant"
}

variable "allowed_access_ips" {
  type        = list(string)
  description = "List of IP addresses/subnets in CIDR format that should be able to access keyvault"
}
