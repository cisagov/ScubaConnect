variable "resource_prefix" {
  type        = string
  description = "Prefix to use in resource names"
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

variable "input_storage_container_url" {
  default     = null
  type        = string
  description = "If not null, input container to read configs from (must give permissions to service account). Otherwise by default will create storage container. Expect an https url pointing to a container"
}

variable "output_storage_container_url" {
  default     = null
  type        = string
  description = "If not null, output container to put results in (must give permissions to service account or use SAS). Otherwise by default will create storage container. Expect an https url pointing to a container"
}

variable "output_storage_container_sas" {
  default     = null
  type        = string
  description = "If not null, shared access signature token (query string) to use when writing results to the output storage container. Set this when the container is in an external tenant (the owner of that container will provide the value)."
  sensitive   = true
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

variable "contact_emails" {
  description = "Emails to notify when container has non-zero exit"
  type        = list(string)
}

variable "log_analytics_workspace" {
  type = object({
    id                 = string
    workspace_id       = string
    primary_shared_key = string
  })
  description = "Log Analytics Workspace container should write logs to"
}

variable "allowed_access_ips" {
  type        = list(string)
  description = "List of IP addresses/subnets in CIDR format that should be able to access storage"
  default     = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnets used for storage and Azure Container Instances"
  default     = null
}

variable "container_registry" {
  type = object({
    server   = string
    username = string
    password = string
  })
  default = null
  description = "Credentials for logging into registry with container image"
}

variable "container_image" {
  type        = string
  description = "Docker image to use for running ScubaGear."
}

variable "container_memory_gb" {
  type        = number
  description = "Amount of memory to allocate for ScubaGear container. Due to memory leaks in some dependencies, this may need to be increased if running on many tenants"
  default     = 3
  validation {
    condition     = var.container_memory_gb <= 16 && var.container_memory_gb >= 2
    error_message = "Container memory must be between 2GB and 16GB"
  }
}

variable "cert_info" {
  description = "Information for obtaining to app certificate"
  type = object({
    vault_id   = string
    vault_name = string
    cert_name  = string
  })
}

variable "secondary_app_info" {
  description = <<EOF
    Information for a secondary app. This can be used for one ScubaConnect instance to handle multiple environments (e.g., GCC and GCC High).
    To use, manually create an app in the other environment and add the certificate created for the primary app to it.
    Set `environment_to_use` to the environment the manual app is in, either "commericial" or "gcchigh"
  EOF
  type = object({
    app_id = string
    environment_to_use = string
  })
  default = null
  validation {
    condition = var.secondary_app_info == null ? true : contains(["commercial", "gcchigh"], var.secondary_app_info.environment_to_use)
    error_message = "Valid values for create_mode are (Default, PointInTimeRestore, Replica)"
  }
}
