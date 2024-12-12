variable "app_name" {
  default     = "ScubaConnect"
  type        = string
  description = "App name. Displayed in Azure console on installed tenants"
}

variable "image_path" {
  default     = "./cisa_logo.png"
  type        = string
  description = "Path to image used for app logo. Displayed in Azure console on installed tenants"
}

variable "create_app" {
  default     = true
  type        = bool
  description = "If true, the app will be created. If false, the app will be imported"
}

variable "prefix_override" {
  default     = null
  type        = string
  description = "Prefix for resource names. If null, one will be generated from app_name"
}

variable "contact_email" {
  description = "Email to notify before certificate expiry"
  type        = string
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

variable "resource_group_name" {
  type        = string
  description = "Resource group to create and build resources in"
}

variable "serial_number" {
  default     = "01"
  type        = string
  description = "Increment by 1 when re-provisioning with the same resource group name"
}

variable "location" {
  default     = "East US"
  type        = string
  description = "Region to build resources in"
}

variable "schedule_interval" {
  default     = "Week"
  type        = string
  description = "The interval to run the scheduled job on."
  validation {
    condition     = contains(["Hour", "Day", "Week", "Month"], var.schedule_interval)
    error_message = "Must be one of 'Hour', 'Day', 'Week', 'Month'"
  }
}

variable "input_storage_container_id" {
  default     = null
  type        = string
  description = "If not null, input container to read configs from (must give permissions to service account). Otherwise by default will create storage container."
}

variable "output_storage_container_id" {
  default     = null
  type        = string
  description = "If not null, output account to put results in (must give permissions to service account). Otherwise by default will create storage container."
}

variable "vnet" {
  type = object({
    address_space          = string
    aci_subnet             = string
    allowed_access_ip_list = list(string)
  })
  description = "Configuration for the vnet, including the address space, ACI subnet, and a list of allowed IP ranges. All strings in CIDR format"
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

variable "container_registry" {
  type = object({
    server   = string
    username = optional(string)
    password = optional(string)
  })
  default = {
    server = "ghcr.io"
  }
  description = "Credentials for logging into registry with container image"
}

variable "container_image" {
  type        = string
  default     = "ghcr.io/cisagov/scubaconnect-m365:latest"
  description = "Docker image to use for running ScubaGear."
}

variable "tenants_dir_path" {
  default     = "./tenants"
  type        = string
  description = "Relative path to directory containing tenant configuration files in yaml"
}