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