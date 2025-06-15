# shared/versions.tf


# shared/providers.tf


# shared/variables.tf


# env/mgmt/main.tf


# env/mgmt/variables.tf


# env/mgmt/terraform.tfvars
rancher_cluster_id = "c-m-mgmt"
rancher_context    = "c-m-mgmt:p-argocd"

int_cluster_id  = "c-m-int"
prod_cluster_id = "c-m-prod"

platform_repo_url = "https://github.com/your-org/argocd-platform.git"

# env/mgmt/outputs.tf


# env/int/main.tf

# env/int/variables.tf


# env/int/terraform.tfvars


# env/prod/main.tf

# env/prod/variables.tf


# env/prod/terraform.tfvars


# modules/argocd-main/main.tf


# modules/argocd-agent/variables.tf


# modules/argocd-agent/outputs.tf


# modules/bootstrap/main.tf

# modules/bootstrap/variables.tf


# modules/bootstrap/outputs.tf


# modules/secret/main.tf

# modules/secret/variables.tf


# modules/secret/outputs.tf


# modules/argocd-main/variables.tf


# modules/argocd-main/outputs.tf


# modules/argocd-agent/main.tf


# env/mgmt/variables.tf

# env/mgmt/outputs.tf


# env/int/main.tf


# env/int/variables.tf
variable "rancher_cluster_id" {
  description = "Rancher integration cluster ID"
  type        = string
}

variable "rancher_context" {
  description = "Rancher Kubernetes context"
  type        = string
}

variable "platform_repo_url" {
  description = "Platform repository URL"
  type        = string
  default     = "https://github.com/your-org/argocd-platform.git"
}

variable "git_token" {
  description = "Git access token for private repositories"
  type        = string
  sensitive   = true
}

# env/int/terraform.tfvars
rancher_cluster_id = "c-m-int"
rancher_context    = "c-m-int:p-integration"

platform_repo_url = "https://github.com/your-org/argocd-platform.git"

# env/int/outputs.tf
output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = module.argocd_agent.argocd_server_url
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = module.argocd_agent.argocd_admin_password
  sensitive   = true
}

# env/prod/main.tf
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

# env/prod/variables.tf
variable "rancher_cluster_id" {
  description = "Rancher production cluster ID"
  type        = string
}

variable "rancher_context" {
  description = "Rancher Kubernetes context"
  type        = string
}

variable "platform_repo_url" {
  description = "Platform repository URL"
  type        = string
  default     = "https://github.com/your-org/argocd-platform.git"
}

variable "git_token" {
  description = "Git access token for private repositories"
  type        = string
  sensitive   = true
}

# env/prod/terraform.tfvars
rancher_cluster_id = "c-m-prod"
rancher_context    = "c-m-prod:p-production"

platform_repo_url = "https://github.com/your-org/argocd-platform.git"

# env/prod/outputs.tf
output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = module.argocd_agent.argocd_server_url
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = module.argocd_agent.argocd_admin_password
  sensitive   = true
}

# modules/argocd-main/main.tf
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
          "application.instanceLabelKey"       = "argocd.argoproj.io/instance"
          "server.rbac.log.enforce.enable"     = "true"
          "accounts.pipeline"                  = "apiKey"
          "accounts.pipeline.enabled"          = "true"
          
          "repositories" = yamlencode([
            {
              type = "git"
              url  = var.platform_repo_url
              name = "platform"
            }
          ])
          
          "clusters" = yamlencode([
            for cluster_name, cluster in var.external_clusters : {
              name   = cluster.name
              server = cluster.server
              config = cluster.config
            }
          ])
        }
        
        params = {
          "server.insecure"                     = "true"
          "application.namespaces"              = "*"
          "controller.diff.server.side"         = "true"
        }
      }
      
      controller = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
      }
      
      server = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        
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
        
        resources = {
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      
      repoServer = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        
        resources = {
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      
      applicationSet = {
        enabled = true
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
      
      notifications = {
        enabled = true
        
        cm = {
          create = true
        }
        
        secret = {
          create = false
          name   = "argocd-notifications-secret"
        }
        
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
    })
  ]
  
  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_secret.argocd_admin
  ]
}

resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]
  
  create_duration = "60s"
}

resource "kubernetes_manifest" "bootstrap_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    
    metadata = {
      name      = "bootstrap"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
      
      labels = merge(var.common_tags, {
        "app.kubernetes.io/name" = "bootstrap"
      })
    }
    
    spec = {
      project = "default"
      
      source = {
        repoURL        = var.platform_repo_url
        targetRevision = "HEAD"
        path           = "bootstrap/${var.environment}"
      }
      
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        
        syncOptions = [
          "CreateNamespace=true"
        ]
        
        retry = {
          limit = 3
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }
  
  depends_on = [time_sleep.wait_for_argocd]
}

resource "kubernetes_secret" "notifications_secret" {
  metadata {
    name      = "argocd-notifications-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  
  data = {
    # Add your notification credentials here
  }
  
  type = "Opaque"
}

# modules/argocd-main/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "rancher_cluster_id" {
  description = "Rancher cluster ID"
  type        = string
}

variable "rancher_context" {
  description = "Rancher Kubernetes context"
  type        = string
}

variable "argocd_hostname" {
  description = "ArgoCD server hostname"
  type        = string
}

variable "platform_repo_url" {
  description = "Platform repository URL"
  type        = string
}

variable "external_clusters" {
  description = "External clusters for cross-cluster management"
  type = map(object({
    server = string
    name   = string
    config = optional(map(string), {})
  }))
  default = {}
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}

# modules/argocd-main/outputs.tf
output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = "https://${var.argocd_hostname}"
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = random_password.argocd_admin.result
  sensitive   = true
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "bootstrap_app_name" {
  description = "Bootstrap application name"
  value       = kubernetes_manifest.bootstrap_app.manifest.metadata.name
}

output "helm_release_status" {
  description = "Helm release status"
  value       = helm_release.argocd.status
}

# modules/argocd-agent/main.tf
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
  depends_on = [helm_release.argocd]
  
  create_duration = "30s"
}

resource "kubernetes_manifest" "local_bootstrap" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    
    metadata = {
      name      = "local-bootstrap"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
      
      labels = merge(var.common_tags, {
        "app.kubernetes.io/name" = "local-bootstrap"
        "environment"            = var.environment
        "cluster"                = var.rancher_cluster_id
      })
    }
    
    spec = {
      project = "default"
      
      source = {
        repoURL        = var.platform_repo_url
        targetRevision = "HEAD"
        path           = "bootstrap/${var.environment}"
      }
      
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      # modules/rancher-rbac/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "rancher_cluster_id" {
  description = "Rancher cluster ID"
  type        = string
}

variable "rancher_projects" {
  description = "Rancher projects to create"
  type = map(object({
    description  = string
    cpu_limit    = string
    memory_limit = string
  }))
  default = {}
}

variable "project_bindings" {
  description = "Project role template bindings"
  type = map(object({
    project = string
    role    = string
    group   = string
  }))
  default = {}
}

variable "cross_cluster_access" {
  description = "Cross-cluster access configuration"
  type        = map(string)
  default     = {}
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}

# modules/rancher-rbac/outputs.tf
output "rancher_projects" {
  description = "Created Rancher projects"
  value = {
    for k, v in rancher2_project.projects : k => {
      id          = v.id
      name        = v.name
      description = v.description
      cluster_id  = v.cluster_id
    }
  }
}

output "project_bindings" {
  description = "Created project role bindings"
  value = {
    for k, v in rancher2_project_role_template_binding.bindings : k => {
      name       = v.name
      project_id = v.project_id
      role       = v.role_template_id
    }
  }
}

output "cross_cluster_tokens" {
  description = "Service account tokens for cross-cluster access"
  value = {
    for k, v in data.kubernetes_secret.argocd_cross_cluster_tokens : k => base64decode(v.data.token)
  }
  sensitive = true
}

output "cross_cluster_service_accounts" {
  description = "Cross-cluster service accounts"
  value = {
    for k, v in kubernetes_service_account.argocd_cross_cluster : k => {
      name      = v.metadata[0].name
      namespace = v.metadata[0].namespace
    }
  }
}

# modules/argocd-main/main.tf
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
          "application.instanceLabelKey"       = "argocd.argoproj.io/instance"
          "server.rbac.log.enforce.enable"     = "true"
          "policy.default"                     = "role:readonly"
          "policy.csv"                         = local.rbac_policy
          "accounts.pipeline"                  = "apiKey"
          "accounts.pipeline.enabled"          = "true"
          
          "repositories" = yamlencode([
            {
              type = "git"
              url  = var.platform_repo_url
              name = "platform"
            }
          ])
          
          "clusters" = yamlencode([
            for cluster_name, cluster in var.external_clusters : {
              name   = cluster.name
              server = cluster.server
              config = cluster.config
            }
          ])
        }
        
        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv"     = local.rbac_policy
        }
        
        params = {
          "server.insecure"                     = "true"
          "application.namespaces"              = "*"
          "controller.diff.server.side"         = "true"
        }
      }
      
      controller = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        
        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
      }
      
      server = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        
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
        
        resources = {
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      
      repoServer = {
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        
        resources = {
          requests = {
            cpu    = "200m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      
      applicationSet = {
        enabled = true
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
      
      notifications = {
        enabled = true
        
        cm = {
          create = true
        }
        
        secret = {
          create = false
          name   = "argocd-notifications-secret"
        }
        
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }
    })
  ]
  
  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_secret.argocd_admin
  ]
}

resource "time_sleep" "wait_for_argocd" {
  depends_on = [helm_release.argocd]
  
  create_duration = "60s"
}

resource "kubernetes_manifest" "bootstrap_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    
    metadata = {
      name      = "bootstrap"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
      
      labels = merge(var.common_tags, {
        "app.kubernetes.io/name" = "bootstrap"
      })
    }
    
    spec = {
      project = "default"
      
      source = {
        repoURL        = var.platform_repo_url
        targetRevision = "HEAD"
        path           = "bootstrap/${var.environment}"
      }
      
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        
        syncOptions = [
          "CreateNamespace=true"
        ]
        
        retry = {
          limit = 3
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }
  
  depends_on = [time_sleep.wait_for_argocd]
}

# modules/argocd-main/rbac.tf
locals {
  rbac_policy = var.rbac_policy != "" ? var.rbac_policy : <<-EOT
    p, role:platform-admin, applications, *, *, allow
    p, role:platform-admin, clusters, *, *, allow
    p, role:platform-admin, repositories, *, *, allow
    p, role:platform-admin, accounts, *, *, allow
    p, role:platform-admin, certificates, *, *, allow
    p, role:platform-admin, gpgkeys, *, *, allow
    p, role:platform-admin, logs, *, *, allow
    p, role:platform-admin, exec, *, *, allow
    
    p, role:release-manager, applications, *, */prod, allow
    p, role:release-manager, applications, *, */int, allow
    p, role:release-manager, applications, get, *, allow
    p, role:release-manager, repositories, get, *, allow
    p, role:release-manager, clusters, get, *, allow
    p, role:release-manager, logs, get, *, allow
    
    p, role:developer, applications, get, *, allow
    p, role:developer, applications, sync, webapp/*, allow
    p, role:developer, applications, sync, api/*, allow
    p, role:developer, applications, sync, backend/*, allow
    p, role:developer, applications, action/*, webapp/*, allow
    p, role:developer, applications, action/*, api/*, allow
    p, role:developer, applications, action/*, backend/*, allow
    p, role:developer, repositories, get, *, allow
    p, role:developer, logs, get, webapp/*, allow
    p, role:developer, logs, get, api/*, allow
    p, role:developer, logs, get, backend/*, allow
    
    p, role:pipeline, applications, get, *, allow
    p, role:pipeline, applications, sync, *, allow
    p, role:pipeline, applications, action/*, *, allow
    p, role:pipeline, repositories, get, *, allow
    
    g, platform-team, role:platform-admin
    g, release-managers, role:release-manager
    g, developers, role:developer
    g, ci-cd-pipeline, role:pipeline
    
    g, argocd:login, role:readonly
  EOT
}

resource "kubernetes_secret" "notifications_secret" {
  metadata {
    name      = "argocd-notifications-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  
  data = {
    # Add your notification credentials here
  }
  
  type = "Opaque"
}

resource "kubernetes_config_map" "notifications_cm" {
  metadata {
    name      = "argocd-notifications-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  
  data = {
    "service.email.gmail" = <<-EOT
      host: smtp.gmail.com
      port: 587
      from: argocd@intern.ch
    EOT
    
    "template.app-deployed" = <<-EOT
      email:
        subject: Application {{.app.metadata.name}} deployed successfully
      message: |
        Application {{.app.metadata.name}} is now running new version.
        
        Application Details:
        - Name: {{.app.metadata.name}}
        - Environment: {{.app.metadata.labels.environment}}
        - Sync Status: {{.app.status.sync.status}}
        - Health Status: {{.app.status.health.status}}
        - ArgoCD: https://${var.argocd_hostname}/applications/{{.app.metadata.name}}
    EOT
    
    "template.app-health-degraded" = <<-EOT
      email:
        subject: Application {{.app.metadata.name}} health degraded
      message: |
        Application {{.app.metadata.name}} health is {{.app.status.health.status}}.
        
        Please check the application status:
        https://${var.argocd_hostname}/applications/{{.app.metadata.name}}
    EOT
    
    "trigger.on-deployed" = <<-EOT
      - description: Application is synced and healthy
        send:
        - app-deployed
        when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
    EOT
    
    "trigger.on-health-degraded" = <<-EOT
      - description: Application has degraded
        send:
        - app-health-degraded
        when: app.status.health.status == 'Degraded'
    EOT
    
    "trigger.on-sync-failed" = <<-EOT
      - description: Application syncing has failed
        send:
        - app-health-degraded
        when: app.status.operationState.phase in ['Error', 'Failed']
    EOT
    
    "subscriptions" = <<-EOT
      - recipients:
        - platform-team@intern.ch
        triggers:
        - on-deployed
        - on-health-degraded
        - on-sync-failed
    EOT
  }
}

# modules/argocd-main/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "rancher_cluster_id" {
  description = "Rancher cluster ID"
  type        = string
}

variable "rancher_context" {
  description = "Rancher Kubernetes context"
  type        = string
}

variable "argocd_hostname" {
  description = "ArgoCD server hostname"
  type        = string
}

variable "platform_repo_url" {
  description = "Platform repository URL"
  type        = string
}

variable "external_clusters" {
  description = "External clusters for cross-cluster management"
  type = map(object({
    server = string
    name   = string
    config = optional(map(string), {})
  }))
  default = {}
}

variable "rbac_policy" {
  description = "Custom RBAC policy for ArgoCD"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}

# modules/argocd-main/outputs.tf
output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = "https://${var.argocd_hostname}"
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = random_password.argocd_admin.result
  sensitive   = true
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "bootstrap_app_name" {
  description = "Bootstrap application name"
  value       = kubernetes_manifest.bootstrap_app.manifest.metadata.name
}

output "helm_release_status" {
  description = "Helm release status"
  value       = helm_release.argocd.status
}

# modules/argocd-agent/main.tf
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
          "policy.default"                 = "role:readonly"
          "policy.csv"                     = local.rbac_policy
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
        
        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv"     = local.rbac_policy
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
  depends_on = [helm_release.argocd]
  
  create_duration = "30s"
}

resource "kubernetes_manifest" "local_bootstrap" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    
    metadata = {
      name      = "local-bootstrap"
      namespace = kubernetes_namespace.argocd.metadata[0].name
      
      finalizers = [
        "resources-finalizer.argocd.argoproj.io"
      ]
      
      labels = merge(var.common_tags, {
        "app.kubernetes.io/name" = "local-bootstrap"
        "environment"            = var.environment
        "cluster"                = var.rancher_cluster_id
      })
    }
    
    spec = {
      project = "default"
      
      source = {
        repoURL        = var.platform_repo_url
        targetRevision = "HEAD"
        path           = "bootstrap/${var.environment}"
      }
      
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = kubernetes_namespace.argocd.metadata[0].name
      }
      
      syncPolicy = var.sync_policy
    }
  }
  
  depends_on = [time_sleep.wait_for_argocd]
}

# modules/argocd-agent/rbac.tf
locals {
  rbac_policy = var.rbac_policy != "" ? var.rbac_policy : <<-EOT
    p, role:local-admin, applications, *, ${var.environment}-*, allow
    p, role:local-admin, applications, *, *, allow
    p, role:local-admin, repositories, get, *, allow
    p, role:local-admin, clusters, get, *, allow
    p, role:local-admin, logs, get, *, allow
    p, role:local-admin, exec, create, ${var.environment}-*, allow
    
    p, role:local-operator, applications, get, *, allow
    p, role:local-operator, applications, sync, *, allow
    p, role:local-operator, applications, action/*, *, allow
    p, role:local-operator, repositories, get, *, allow
    p, role:local-operator, logs, get, *, allow
    
    p, role:pipeline, applications, get, *, allow
    p, role:pipeline, applications, sync, *, allow
    p, role:pipeline, applications, action/*, *, allow
    p, role:pipeline, repositories, get, *, allow
    
    p, role:local-readonly, applications, get, *, allow
    p, role:local-readonly, repositories, get, *, allow
    p, role:local-readonly, clusters, get, *, allow
    
    g, ${var.environment}-admins, role:local-admin
    g, ${var.environment}-operators, role:local-operator
    g, ${var.environment}-viewers, role:local-readonly
    g, ci-cd-pipeline, role:pipeline
    
    ${var.environment == "prod" ? "# No default access in production" : "g, argocd:login, role:local-readonly"}
  EOT
}

# modules/argocd-agent/variables.tf
variable "environment" {
  description = "Environment name (int, prod)"
  type        = string
}

variable "rancher_cluster_id" {
  description = "Rancher cluster ID"
  type        = string
}

variable "rancher_context" {
  description = "Rancher Kubernetes context"
  type        = string
}

variable "argocd_hostname" {
  description = "ArgoCD server hostname"
  type        = string
}

variable "platform_repo_url" {
  description = "Platform repository URL"
  type        = string
}

variable "rbac_policy" {
  description = "Local RBAC policy for this cluster"
  type        = string
  default     = ""
}

variable "sync_policy" {
  description = "Default sync policy for applications"
  type = object({
    automated = object({
      prune    = optional(bool, true)
      selfHeal = optional(bool, true)
    })
  })
  default = {
    automated = {
      prune    = false
      selfHeal = true
    }
  }
}

variable "resource_quotas" {
  description = "Resource quotas for ArgoCD components"
  type = object({
    controller = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    server = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
    repo_server = object({
      requests = object({
        cpu    = string
        memory = string
      })
      limits = object({
        cpu    = string
        memory = string
      })
    })
  })
  default = {
    controller = {
      requests = {
        cpu    = "250m"
        memory = "1Gi"
      }
      limits = {
        cpu    = "500m"
        memory = "2Gi"
      }
    }
    server = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "256Mi"
      }
    }
    repo_server = {
      requests = {
        cpu    = "100m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "256Mi"
      }
    }
  }
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}

# modules/argocd-agent/outputs.tf
output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = "https://${var.argocd_hostname}"
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = random_password.argocd_admin.result
  sensitive   = true
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "local_bootstrap_app" {
  description = "Local bootstrap application name"
  value       = kubernetes_manifest.local_bootstrap.manifest.metadata.name
}

output "helm_release_status" {
  description = "Helm release status"
  value       = helm_release.argocd.status
}

# modules/bootstrap/main.tf
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
    
    labels = merge(var.common_tags, {
      "app.kubernetes.io/name"                = "cert-manager"
      "pod-security.kubernetes.io/enforce"    = "restricted"
      "pod-security.kubernetes.io/audit"      = "restricted"
      "pod-security.kubernetes.io/warn"       = "restricted"
    })
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    
    labels = merge(var.common_tags, {
      "app.kubernetes.io/name"                = "monitoring"
      "pod-security.kubernetes.io/enforce"    = "privileged"
      "pod-security.kubernetes.io/audit"      = "privileged"
      "pod-security.kubernetes.io/warn"       = "privileged"
    })
  }
}

resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
    
    labels = merge(var.common_tags, {
      "app.kubernetes.io/name"                = "ingress-nginx"
      "pod-security.kubernetes.io/enforce"    = "privileged"
      "pod-security.kubernetes.io/audit"      = "privileged"
      "pod-security.kubernetes.io/warn"       = "privileged"
    })
  }
}

resource "kubernetes_namespace" "security" {
  count = var.environment == "prod" ? 1 : 0
  
  metadata {
    name = "security"
    
    labels = merge(var.common_tags, {
      "app.kubernetes.io/name"                = "security"
      "pod-security.kubernetes.io/enforce"    = "restricted"
      "pod-security.kubernetes.io/audit"      = "restricted"
      "pod-security.kubernetes.io/warn"       = "restricted"
    })
  }
}

resource "kubernetes_namespace" "environment_apps" {
  metadata {
    name = var.environment
    
    labels = merge(var.common_tags, {
      "app.kubernetes.io/name" = "${var.environment}-apps"
      "environment"            = var.environment
    })
  }
}

# modules/bootstrap/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_id" {
  description = "Cluster ID"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}

# modules/bootstrap/outputs.tf
output "status" {
  description = "Bootstrap status"
  value = {
    environment = var.environment
    cluster     = var.cluster_id
    namespaces_created = compact([
      kubernetes_namespace.cert_manager.metadata[0].name,
      kubernetes_namespace.monitoring.metadata[0].name,
      kubernetes_namespace.ingress_nginx.metadata[0].name,
      try(kubernetes_namespace.security[0].metadata[0].name, ""),
      kubernetes_namespace.environment_apps.metadata[0].name
    ])
  }
}

output "namespaces" {
  description = "Created namespaces"
  value = {
    cert_manager    = kubernetes_namespace.cert_manager.metadata[0].name
    monitoring      = kubernetes_namespace.monitoring.metadata[0].name
    ingress_nginx   = kubernetes_namespace.ingress_nginx.metadata[0].name
    security        = try(kubernetes_namespace.security[0].metadata[0].name, null)
    environment     = kubernetes_namespace.environment_apps.metadata[0].name
  }
}

# modules/secret/main.tf
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

resource "kubernetes_secret" "git_token" {
  count = var.secrets.git_token != null ? 1 : 0
  
  metadata {
    name      = "git-repository-secret"
    namespace = "argocd"
    
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }
  
  data = {
    type     = "git"
    url      = "https://github.com/your-org"
    password = var.secrets.git_token
    username = "git"
  }
  
  type = "Opaque"
}

resource "kubernetes_secret" "docker_registry" {
  count = var.secrets.docker_registry != null ? 1 : 0
  
  metadata {
    name      = "docker-registry-secret"
    namespace = "argocd"
  }
  
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "registry.intern.ch" = {
          username = var.secrets.docker_registry.username
          password = var.secrets.docker_registry.password
          auth     = base64encode("${var.secrets.docker_registry.username}:${var.secrets.docker_registry.password}")
        }
      }
    })
  }
  
  type = "kubernetes.io/dockerconfigjson"
}

# modules/secret/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "secrets" {
  description = "Secrets configuration"
  type = object({
    git_token = optional(string)
    docker_registry = optional(object({
      username = string
      password = string
    }))
  })
  default = {}
  sensitive = true
}

# modules/secret/outputs.tf
output "secrets_configured" {
  description = "List of configured secrets"
  value = {
    git_token       = var.secrets.git_token != null ? "configured" : "not configured"
    docker_registry = var.secrets.docker_registry != null ? "configured" : "not configured"
  }
}# shared/versions.tf
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 4.0"
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

# shared/providers.tf
terraform {
  # Minio S3 Backend will be configured per environment
  backend "s3" {}
}

provider "rancher2" {
  api_url    = var.rancher_url
  access_key = var.rancher_access_key
  secret_key = var.rancher_secret_key
}

locals {
  common_tags = {
    Project     = "argocd-platform"
    ManagedBy   = "terraform"
    Environment = var.environment
  }
  
  argocd_version = "5.51.6"
}

# shared/variables.tf
variable "environment" {
  description = "Environment name (mgmt, int, prod)"
  type        = string
}

variable "rancher_url" {
  description = "Rancher server URL"
  type        = string
}

variable "rancher_access_key" {
  description = "Rancher access key"
  type        = string
  sensitive   = true
}

variable "rancher_secret_key" {
  description = "Rancher secret key"
  type        = string
  sensitive   = true
}

# env/mgmt/main.tf
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
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 4.0"
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

provider "rancher2" {
  api_url    = var.rancher_url
  access_key = var.rancher_access_key
  secret_key = var.rancher_secret_key
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

module "rancher_rbac" {
  source = "../../modules/rancher-rbac"
  
  environment        = local.environment
  rancher_cluster_id = var.rancher_cluster_id
  
  rancher_projects = {
    "argocd-platform" = {
      description  = "ArgoCD Platform Management"
      cpu_limit    = "10000m"
      memory_limit = "20Gi"
    }
    "monitoring" = {
      description  = "Monitoring Infrastructure"
      cpu_limit    = "5000m"
      memory_limit = "10Gi"
    }
    "security" = {
      description  = "Security Tools"
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
  }
  
  project_bindings = var.project_bindings
  
  cross_cluster_access = {
    int_cluster  = var.int_cluster_id
    prod_cluster = var.prod_cluster_id
  }
  
  common_tags = local.common_tags
}

module "bootstrap" {
  source = "../../modules/bootstrap"
  
  environment    = local.environment
  cluster_id     = var.rancher_cluster_id
  common_tags    = local.common_tags
  
  depends_on = [module.rancher_rbac]
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
      config = {
        bearerToken = module.rancher_rbac.cross_cluster_tokens["int_cluster"]
      }
    }
    "prod-cluster" = {
      server = "https://rancher.intern.ch/k8s/clusters/${var.prod_cluster_id}"
      name   = var.prod_cluster_id
      config = {
        bearerToken = module.rancher_rbac.cross_cluster_tokens["prod_cluster"]
      }
    }
  }
  
  rbac_policy = var.rbac_policy
  common_tags = local.common_tags
  
  depends_on = [module.bootstrap, module.secrets]
}

# env/mgmt/variables.tf
variable "rancher_url" {
  description = "Rancher server URL"
  type        = string
  default     = "https://rancher.intern.ch"
}

variable "rancher_access_key" {
  description = "Rancher access key"
  type        = string
  sensitive   = true
}

variable "rancher_secret_key" {
  description = "Rancher secret key"
  type        = string
  sensitive   = true
}

variable "rancher_cluster_id" {
  description = "Rancher management cluster ID"
  type        = string
}

variable "rancher_context" {
  description = "Rancher Kubernetes context"
  type        = string
}

variable "int_cluster_id" {
  description = "Integration cluster ID for cross-cluster access"
  type        = string
}

variable "prod_cluster_id" {
  description = "Production cluster ID for cross-cluster access"
  type        = string
}

variable "platform_repo_url" {
  description = "Platform repository URL"
  type        = string
  default     = "https://github.com/your-org/argocd-platform.git"
}

variable "git_token" {
  description = "Git access token for private repositories"
  type        = string
  sensitive   = true
}

variable "project_bindings" {
  description = "Rancher project role bindings"
  type = map(object({
    project = string
    role    = string
    group   = string
  }))
  default = {}
}

variable "rbac_policy" {
  description = "ArgoCD RBAC policy"
  type        = string
  default     = ""
}

# env/mgmt/terraform.tfvars
rancher_url        = "https://rancher.intern.ch"
rancher_cluster_id = "c-m-mgmt"
rancher_context    = "c-m-mgmt:p-argocd"

int_cluster_id  = "c-m-int"
prod_cluster_id = "c-m-prod"

platform_repo_url = "https://github.com/your-org/argocd-platform.git"

project_bindings = {
  "platform-admins" = {
    project = "argocd-platform"
    role    = "project-owner"
    group   = "platform-team"
  }
  "developers" = {
    project = "argocd-platform"
    role    = "project-member"
    group   = "developers"
  }
  "monitoring-team" = {
    project = "monitoring"
    role    = "project-owner"
    group   = "monitoring-team"
  }
}

rbac_policy = <<-EOT
p, role:platform-admin, applications, *, *, allow
p, role:platform-admin, clusters, *, *, allow
p, role:platform-admin, repositories, *, *, allow
p, role:platform-admin, accounts, *, *, allow

p, role:release-manager, applications, *, */prod, allow
p, role:release-manager, applications, *, */int, allow
p, role:release-manager, applications, get, *, allow

p, role:developer, applications, get, *, allow
p, role:developer, applications, sync, webapp/*, allow
p, role:developer, applications, sync, api/*, allow
p, role:developer, applications, sync, backend/*, allow

g, platform-team, role:platform-admin
g, release-managers, role:release-manager
g, developers, role:developer

g, argocd:login, role:readonly
EOT

# env/mgmt/outputs.tf
output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = module.argocd_main.argocd_server_url
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = module.argocd_main.argocd_admin_password
  sensitive   = true
}

output "rancher_projects" {
  description = "Created Rancher projects"
  value       = module.rancher_rbac.rancher_projects
}

output "cross_cluster_tokens" {
  description = "Cross-cluster service account tokens"
  value       = module.rancher_rbac.cross_cluster_tokens
  sensitive   = true
}

# env/int/main.tf
terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    endpoint                    = "https://minio.intern.ch"
    bucket                     = "terraform-state"
    key                        = "argocd/int/terraform.tfstate"
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
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 4.0"
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

provider "rancher2" {
  api_url    = var.rancher_url
  access_key = var.rancher_access_key
  secret_key = var.rancher_secret_key
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
  environment = "int"
  argocd_hostname = "argocd.int.intern.ch"
  common_tags = {
    Environment = local.environment
    Project     = "argocd-platform"
    ManagedBy   = "terraform"
    Cluster     = var.rancher_cluster_id
  }
}

module "rancher_rbac" {
  source = "../../modules/rancher-rbac"
  
  environment        = local.environment
  rancher_cluster_id = var.rancher_cluster_id
  
  rancher_projects = {
    "integration" = {
      description  = "Integration Environment"
      cpu_limit    = "5000m"
      memory_limit = "10Gi"
    }
    "monitoring" = {
      description  = "Monitoring Infrastructure"
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
  }
  
  project_bindings = var.project_bindings
  common_tags      = local.common_tags
}

module "bootstrap" {
  source = "../../modules/bootstrap"
  
  environment = local.environment
  cluster_id  = var.rancher_cluster_id
  common_tags = local.common_tags
  
  depends_on = [module.rancher_rbac]
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
      prune    = true
      selfHeal = true
    }
  }
  
  resource_quotas = {
    controller = {
      requests = {
        cpu    = "250m"
        memory = "1Gi"
      }
      limits = {
        cpu    = "500m"
        memory = "2Gi"
      }
    }
    server = {
      requests = {
        cpu    = "100m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "512Mi"
      }
    }
    repo_server = {
      requests = {
        cpu    = "100m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "512Mi"
      }
    }
  }
  
  rbac_policy = var.rbac_policy
  common_tags = local.common_tags
  
  depends_on = [module.bootstrap, module.secrets]
}

# env/int/variables.tf
variable "rancher_url" {
  description = "Rancher server URL"
  type        = string
  default     = "https://rancher.intern.ch"
}

variable "rancher_access_key" {
  description = "Rancher access key"
  type        = string
  sensitive   = true
}

variable "rancher_secret_key" {
  description = "Rancher secret key"
  type        = string
  sensitive   = true
}

variable "rancher_cluster_id" {
  description = "Rancher integration cluster ID"
  type        = string
}

variable "rancher_context" {
  description = "Rancher Kubernetes context"
  type        = string
}

variable "platform_repo_url" {
  description = "Platform repository URL"
  type        = string
  default     = "https://github.com/your-org/argocd-platform.git"
}

variable "git_token" {
  description = "Git access token for private repositories"
  type        = string
  sensitive   = true
}

variable "project_bindings" {
  description = "Rancher project role bindings"
  type = map(object({
    project = string
    role    = string
    group   = string
  }))
  default = {}
}

variable "rbac_policy" {
  description = "ArgoCD RBAC policy"
  type        = string
  default     = ""
}

# env/int/terraform.tfvars
rancher_url        = "https://rancher.intern.ch"
rancher_cluster_id = "c-m-int"
rancher_context    = "c-m-int:p-integration"

platform_repo_url = "https://github.com/your-org/argocd-platform.git"

project_bindings = {
  "int-admins" = {
    project = "integration"
    role    = "project-owner"
    group   = "integration-team"
  }
  "developers" = {
    project = "integration"
    role    = "project-member"
    group   = "developers"
  }
}

rbac_policy = <<-EOT
p, role:int-admin, applications, *, int-*, allow
p, role:int-admin, repositories, get, *, allow
p, role:int-admin, clusters, get, *, allow

p, role:developer, applications, *, *, allow
p, role:developer, repositories, get, *, allow

g, integration-team, role:int-admin
g, developers, role:developer

g, argocd:login, role:readonly
EOT

# env/int/outputs.tf
output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = module.argocd_agent.argocd_server_url
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = module.argocd_agent.argocd_admin_password
  sensitive   = true
}

output "rancher_projects" {
  description = "Created Rancher projects"
  value       = module.rancher_rbac.rancher_projects
}

# env/prod/main.tf
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
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 4.0"
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

provider "rancher2" {
  api_url    = var.rancher_url
  access_key = var.rancher_access_key
  secret_key = var.rancher_secret_key
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

module "rancher_rbac" {
  source = "../../modules/rancher-rbac"
  
  environment        = local.environment
  rancher_cluster_id = var.rancher_cluster_id
  
  rancher_projects = {
    "production" = {
      description  = "Production Applications"
      cpu_limit    = "20000m"
      memory_limit = "40Gi"
    }
    "monitoring" = {
      description  = "Production Monitoring"
      cpu_limit    = "5000m"
      memory_limit = "10Gi"
    }
    "security" = {
      description  = "Production Security"
      cpu_limit    = "2000m"
      memory_limit = "4Gi"
    }
  }
  
  project_bindings = var.project_bindings
  common_tags      = local.common_tags
}

module "bootstrap" {
  source = "../../modules/bootstrap"
  
  environment = local.environment
  cluster_id  = var.rancher_cluster_id
  common_tags = local.common_tags
  
  depends_on = [module.rancher_rbac]
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
  
  rbac_policy = var.rbac_policy
  common_tags = local.common_tags
  
  depends_on = [module.bootstrap, module.secrets]
}

# env/prod/variables.tf
variable "rancher_url" {
  description = "Rancher server URL"
  type        = string
  default     = "https://rancher.intern.ch"
}

variable "rancher_access_key" {
  description = "Rancher access key"
  type        = string
  sensitive   = true
}

variable "rancher_secret_key" {
  description = "Rancher secret key"
  type        = string
  sensitive   = true
}

variable "rancher_cluster_id" {
  description = "Rancher production cluster ID"
  type        = string
}

variable "rancher_context" {
  description = "Rancher Kubernetes context"
  type        = string
}

variable "platform_repo_url" {
  description = "Platform repository URL"
  type        = string
  default     = "https://github.com/your-org/argocd-platform.git"
}

variable "git_token" {
  description = "Git access token for private repositories"
  type        = string
  sensitive   = true
}

variable "project_bindings" {
  description = "Rancher project role bindings"
  type = map(object({
    project = string
    role    = string
    group   = string
  }))
  default = {}
}

variable "rbac_policy" {
  description = "ArgoCD RBAC policy"
  type        = string
  default     = ""
}

# env/prod/terraform.tfvars
rancher_url        = "https://rancher.intern.ch"
rancher_cluster_id = "c-m-prod"
rancher_context    = "c-m-prod:p-production"

platform_repo_url = "https://github.com/your-org/argocd-platform.git"

project_bindings = {
  "prod-admins" = {
    project = "production"
    role    = "project-owner"
    group   = "production-admins"
  }
  "prod-operators" = {
    project = "production"
    role    = "project-member"
    group   = "production-operators"
  }
  "monitoring-team" = {
    project = "monitoring"
    role    = "project-owner"
    group   = "monitoring-team"
  }
}

rbac_policy = <<-EOT
p, role:prod-admin, applications, *, *, allow
p, role:prod-admin, repositories, get, *, allow
p, role:prod-admin, clusters, get, *, allow
p, role:prod-admin, logs, get, *, allow

p, role:prod-operator, applications, get, *, allow
p, role:prod-operator, applications, sync, *, allow
p, role:prod-operator, applications, action/*, *, allow
p, role:prod-operator, repositories, get, *, allow
p, role:prod-operator, logs, get, *, allow

p, role:monitoring, applications, get, *, allow
p, role:monitoring, repositories, get, *, allow

g, production-admins, role:prod-admin
g, production-operators, role:prod-operator
g, monitoring-team, role:monitoring

g, argocd:login, ""
EOT

# env/prod/outputs.tf
output "argocd_server_url" {
  description = "ArgoCD server URL"
  value       = module.argocd_agent.argocd_server_url
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value       = module.argocd_agent.argocd_admin_password
  sensitive   = true
}

output "rancher_projects" {
  description = "Created Rancher projects"
  value       = module.rancher_rbac.rancher_projects
}

# modules/rancher-rbac/main.tf
terraform {
  required_providers {
    rancher2 = {
      source  = "rancher/rancher2"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

resource "rancher2_project" "projects" {
  for_each = var.rancher_projects
  
  name       = each.key
  cluster_id = var.rancher_cluster_id
  
  description = each.value.description
  
  resource_quota {
    project_limit {
      limits_cpu      = each.value.cpu_limit
      limits_memory   = each.value.memory_limit
      requests_cpu    = "100m"
      requests_memory = "128Mi"
    }
  }
  
  container_default_resource_limit {
    limits_cpu      = "200m"
    limits_memory   = "256Mi"
    requests_cpu    = "50m"
    requests_memory = "64Mi"
  }
}

resource "rancher2_project_role_template_binding" "bindings" {
  for_each = var.project_bindings
  
  name             = each.key
  project_id       = rancher2_project.projects[each.value.project].id
  role_template_id = each.value.role
  
  group_principal_id = "local://${each.value.group}"
}

resource "kubernetes_service_account" "argocd_cross_cluster" {
  for_each = var.cross_cluster_access
  
  metadata {
    name      = "argocd-${each.key}"
    namespace = "cattle-system"
    
    labels = {
      "app.kubernetes.io/name"       = "argocd-cross-cluster"
      "app.kubernetes.io/managed-by" = "terraform"
      "cluster"                      = each.value
    }
  }
}

resource "kubernetes_cluster_role_binding" "argocd_cross_cluster" {
  for_each = var.cross_cluster_access
  
  metadata {
    name = "argocd-${each.key}-cluster-admin"
    
    labels = {
      "app.kubernetes.io/name"       = "argocd-cross-cluster"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.argocd_cross_cluster[each.key].metadata[0].name
    namespace = kubernetes_service_account.argocd_cross_cluster[each.key].metadata[0].namespace
  }
}

data "kubernetes_secret" "argocd_cross_cluster_tokens" {
  for_each = var.cross_cluster_access
  
  metadata {
    name      = kubernetes_service_account.argocd_cross_cluster[each.key].default_secret_name
    namespace = "cattle-system"
  }
  
  depends_on = [
    kubernetes_service_account.argocd_cross_cluster,
    kubernetes_cluster_role_binding.argocd_cross_cluster
  ]
}

# modules/rancher-rbac/variables.tf
variable "environment" {
  description = "Environment name"
  type        = string
}

variable "rancher_cluster_id" {
  description = "Rancher cluster ID"
  type        = string
}

variable "rancher_projects" {
  description = "Rancher projects to create"
  type = map(object({
    description  = string
    cpu_limit    = string
    memory_limit = string
  }))
  default = {}