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