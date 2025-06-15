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