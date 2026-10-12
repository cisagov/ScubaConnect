terraform {
  required_version = ">= 1.2.0"

  # maintain state file in GCS. Terraform should automatically use if gcp credentials are set
  # backend "gcs" {
  #   bucket = "your-gcs-bucket-name"
  # }
}

provider "google" {
  project = "TODO-your-gcp-project"  # TODO: set your GCP project ID
  region  = "us-east4"               # TODO: set your region (default: us-east4 / Virginia)
  default_labels = {
    # add any labels here to apply to all resources
  }
}
