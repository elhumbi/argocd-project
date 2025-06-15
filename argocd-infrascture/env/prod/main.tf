terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    endpoint                    = "https://minio.intern.ch"
    bucket                     = "terraform-state"
    key                        = "argocd/prod/terraform.tfstate"
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
  environment = "prod"
  argocd_hostname = "argocd.prod.intern.ch"
  common_tags = {
    Environment = local.environment
    Project     = "argocd-platform"
    ManagedBy   = "terraform"
    Cluster     = var.rancher_cluster_id
    Criticality = "high"
  }
}

module "bootstrap" {
  source = "../../modules/bootstrap"
  
  environment = local.environment
  cluster_id  = var.rancher_cluster_id
  common_tags = local.common_tags
}

module "secrets" {
  source = "../../modules/secret"
  
  environment = local.environment
  secrets = {
    git_token = var.git_token
  }
  
  depends_on = [module.bootstrap]
}

module "argocd_agent" {
  source = "../../modules/argocd-agent"
  
  environment         = local.environment
  rancher_cluster_id  = var.rancher_cluster_id
  rancher_context     = var.rancher_context
  argocd_hostname     = local.argocd_hostname
  platform_repo_url   = var.platform_repo_url
  
  sync_policy = {
    automated = {
      prune    = false
      selfHeal = false
    }
  }
  
  resource_quotas = {
    controller = {
      requests = {
        cpu    = "500m"
        memory = "2Gi"
      }
      limits = {
        cpu    = "1000m"
        memory = "4Gi"
      }
    }
    server = {
      requests = {
        cpu    = "200m"
        memory = "512Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "1Gi"
      }
    }
    repo_server = {
      requests = {
        cpu    = "200m"
        memory = "512Mi"
      }
      limits = {
        cpu    = "500m"
        memory = "1Gi"
      }
    }
  }
  
  common_tags = local.common_tags
  
  depends_on = [module.bootstrap, module.secrets]
}
