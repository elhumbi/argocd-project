terraform {
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

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    
    labels = merge(var.common_tags, {
      "app.kubernetes.io/name"                = "argocd"
      "app.kubernetes.io/part-of"             = "argocd"
      "environment"                           = var.environment
      "pod-security.kubernetes.io/enforce"    = "privileged"
      "pod-security.kubernetes.io/audit"      = "privileged"
      "pod-security.kubernetes.io/warn"       = "privileged"
    })
  }
}

resource "random_password" "argocd_admin" {
  length  = 32
  special = true
}

resource "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    
    labels = {
      "app.kubernetes.io/name"    = "argocd-initial-admin-secret"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }
  
  data = {
    password = bcrypt(random_password.argocd_admin.result)
  }
  
  type = "Opaque"
}

resource "kubernetes_secret" "repo_credentials" {
  metadata {
    name      = "repo-credentials"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }
  
  data = {
    type = "git"
    url  = var.platform_repo_url
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  
  wait             = true
  timeout          = 600
  create_namespace = false
  
  values = [
    yamlencode({
      global = {
        domain = var.argocd_hostname
        logging = {
          level  = "info"
          format = "json"
        }
      }
      
      crds = {
        install = true
        keep    = true
      }
      
      configs = {
        cm = {
          "application.instanceLabelKey"   = "argocd.argoproj.io/instance"
          "server.rbac.log.enforce.enable" = "true"
          "accounts.pipeline"              = "apiKey"
          "accounts.pipeline.enabled"      = "true"
          
          "repositories" = yamlencode([
            {
              type = "git"
              url  = var.platform_repo_url
              name = "platform"
            }
          ])
        }
        
        params = {
          "server.insecure"            = "true"
          "application.namespaces"     = "*"
          "controller.diff.server.side" = "true"
        }
      }
      
      controller = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        
        resources = var.resource_quotas.controller
      }
      
      server = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        
        resources = var.resource_quotas.server
        
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          
          hosts = [var.argocd_hostname]
          
          tls = [{
            secretName = "argocd-server-tls"
            hosts      = [var.argocd_hostname]
          }]
          
          annotations = {
            "cert-manager.io/cluster-issuer"                 = "rancher"
            "nginx.ingress.kubernetes.io/ssl-redirect"       = "true"
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
            "nginx.ingress.kubernetes.io/backend-protocol"   = "GRPC"
          }
        }
        
        extraArgs = [
          "--insecure"
        ]
      }
      
      repoServer = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        
        resources = var.resource_quotas.repo_server
      }
      
      dex = {
        enabled = false
      }
      
      notifications = {
        enabled = false
      }
      
      applicationSet = {
        enabled = false
      }
    })
  ]
  
  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_secret.argocd_admin
  ]
}

resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release# env/mgmt/main.tf
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