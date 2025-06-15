terraform {
  backend "s3" {}
}

locals {
  common_tags = {
    Project     = "argocd-platform"
    ManagedBy   = "terraform"
    Environment = var.environment
  }
  
  argocd_version = "5.51.6"
}