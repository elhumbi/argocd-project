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