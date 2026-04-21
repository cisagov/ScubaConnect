terraform {
  required_version = ">= 1.1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "7.28.0"
    }
  }

  # maintain state file in GCS. Terraform should automatically use if gcp credentials are set
  # backend "gcs" {
  #   bucket = "your-gcs-bucket-name"
  # }
}

provider "google" {
  project = var.project
  region  = var.region
  default_labels = {
    # add any labels here to apply to all resources
  }
}

