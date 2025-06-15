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
