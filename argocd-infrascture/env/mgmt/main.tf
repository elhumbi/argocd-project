terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    endpoint                    = "https://minio.intern.ch"
    bucket                     = "terraform-state"
    key                        = "argocd/mgmt/terraform.tfstate"
    region                     = "us-east-1"
    force_path_style           = true
    skip_credentials_validation = true
    skip_metadata_api_check    = true
    skip_region_validation     = true
  }
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = var.rancher_context
}

provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = var.rancher_context
  }
}

locals {
  environment = "mgmt"
  argocd_hostname = "argocd.intern.ch"
  common_tags = {
    Environment = local.environment
    Project     = "argocd-platform"
    ManagedBy   = "terraform"
    Cluster     = var.rancher_cluster_id
  }
}

module "bootstrap" {
  source = "../../modules/bootstrap"
  
  environment    = local.environment
  cluster_id     = var.rancher_cluster_id
  common_tags    = local.common_tags
}

module "secrets" {
  source = "../../modules/secret"
  
  environment = local.environment
  secrets = {
    git_token = var.git_token
  }
  
  depends_on = [module.bootstrap]
}

module "argocd_main" {
  source = "../../modules/argocd-main"
  
  environment           = local.environment
  rancher_cluster_id    = var.rancher_cluster_id
  rancher_context       = var.rancher_context
  argocd_hostname       = local.argocd_hostname
  platform_repo_url     = var.platform_repo_url
  
  external_clusters = {
    "int-cluster" = {
      server = "https://rancher.intern.ch/k8s/clusters/${var.int_cluster_id}"
      name   = var.int_cluster_id
    }
    "prod-cluster" = {
      server = "https://rancher.intern.ch/k8s/clusters/${var.prod_cluster_id}"
      name   = var.prod_cluster_id
    }
  }
  
  common_tags = local.common_tags
  
  depends_on = [module.bootstrap, module.secrets]
}