terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.17.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "3.12.0"
    }
  }
}


provider "helm" {
  kubernetes {
    config_context = var.k8s_config_context
    config_path    = var.k8s_config_path
  }
}

provider "kubernetes" {
  config_context = var.k8s_config_context
  config_path    = var.k8s_config_path
}

provider "vault" {
  address = var.vault_address
  token   = var.vault_token
}

## Namespaces in Kubernetes 
# Namespace in Kubernetes for static secrets
resource "kubernetes_namespace" "app" {
  metadata {
    name = "app"
  }
}

resource "kubernetes_namespace" "demo_ns" {
  metadata {
    name = "demo-ns"
  }
}

resource "kubernetes_namespace" "nginx" {
  metadata {
    name = "nginx"
  }
}