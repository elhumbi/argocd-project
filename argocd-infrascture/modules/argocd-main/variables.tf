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