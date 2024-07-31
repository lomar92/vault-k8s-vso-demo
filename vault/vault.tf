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


resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault"
  create_namespace = true

  set {
    name  = "server.dev.enabled"
    value = "true"
  }

  set {
    name  = "server.dev.devRootToken"
    value = "root"
  }

  set {
    name  = "server.logLevel"
    value = "debug"
  }

  set {
    name  = "ui.enabled"
    value = "true"
  }

  set {
    name  = "ui.externalPort"
    value = "8200"
  }

  set {
    name  = "injector.enabled"
    value = "false"
  }
}
