output "secrets_configured" {
  description = "List of configured secrets"
  value = {
    git_token       = var.secrets.git_token != null ? "configured" : "not configured"
    docker_registry = var.secrets.docker_registry != null ? "configured" : "not configured"
  }
}.argocd]
  
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