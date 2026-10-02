terraform {
  required_version = ">= 1.1.0"

  # maintain state file in Azure storage. Terraform should automatically use if Azure credentials are set
  # Uncomment and configure for production use. See https://developer.hashicorp.com/terraform/language/backend/azurerm
  # backend "azurerm" {
  #   resource_group_name  = "your-tfstate-rg"
  #   storage_account_name = "yourtfstatestorage"
  #   container_name       = "tfstate"
  #   key                  = "scubaconnect.tfstate"
  # }
}

provider "azurerm" {
  subscription_id = "TODO-your-subscription-uuid"  # TODO: set your Azure Subscription ID (from `az account show`)
  environment     = "public"  # Set to "usgovernment" for GCC High
  features {}
}

provider "azuread" {
  environment = "public"  # Set to "usgovernment" for GCC High
}
