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