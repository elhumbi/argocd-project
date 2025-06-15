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
