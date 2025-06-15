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
