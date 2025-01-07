variable "resource_prefix" {
  type        = string
  description = "Prefix to use in resource names"
}

variable "application_pfx_b64" {
  sensitive   = true
  description = "The PFX ceritificate for the application in base64 encoding"
  type        = string
}

variable "application_client_id" {
  description = "The client ID of the application"
  type        = string
}

variable "application_object_id" {
  description = "Object ID of application. Only used if creating output storage; otherwise user must configure permissions"
  type        = string
}

variable "schedule_interval" {
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
  description = "If not null, output container to put results in (must give permissions to service account). Otherwise by default will create storage container."
}

variable "tenants_dir_path" {
  default     = "./tenants"
  type        = string
  description = "Relative path to directory containing tenant configuration files in yaml"
}

variable "resource_group" {
  type = object({
    name     = string
    location = string
    id       = string
  })
  description = "Resource group resources should be created in"
}

variable "contact_email" {
  description = "Email to notify when container has non-zero exit"
  type        = string
}

variable "log_analytics_workspace" {
  type = object({
    id              = string
    workspace_id       = string
    primary_shared_key = string
  })
  description = "Log Analytics Workspace container should write logs to"
}

variable "allowed_access_ips" {
  type        = list(string)
  description = "List of IP addresses/subnets in CIDR format that should be able to access storage"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnets used for storage and Azure Container Instances"
}

variable "container_registry" {
  type = object({
    server   = string
    username = optional(string)
    password = optional(string)
  })
  description = "Credentials for logging into registry with container image"
}

variable "container_image" {
  type        = string
  description = "Docker image to use for running ScubaGear."
}
