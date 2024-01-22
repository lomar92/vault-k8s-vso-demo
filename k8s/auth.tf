# Static Auth 

# KV v2 Secrets Engine aktivieren
resource "vault_mount" "kvv2" {
  path        = "kvv2"
  type        = "kv"
  options     = { version = "2" }
  description = "static secret for app"
}

# Static Secret in KV v2 speichern
resource "vault_kv_secret_v2" "webapp_config" {
  mount = vault_mount.kvv2.path
  name  = "webapp/config"

  data_json = jsonencode(
    {
      username = "static-user"
      password = "static-password"
    }
  )

}

# Vault Policy erstellen
resource "vault_policy" "dev" {
  name   = "dev"
  policy = <<EOT
path "kvv2/*" {
  capabilities = ["read"]
}
EOT
}

# Authentifizierungsmethode in Vault aktivieren
# kubernetes auth enable
resource "vault_auth_backend" "default" {
  path = "demo-auth-mount"
  type = "kubernetes"
}

# Konfiguration des Authentifizierungsmethode in Vault
resource "vault_kubernetes_auth_backend_config" "config" {
  backend         = vault_auth_backend.default.path
  kubernetes_host = "https://kubernetes.default.svc:443"
}

# Vault Kubernetes Role erstellen static app
resource "vault_kubernetes_auth_backend_role" "role1" {
  role_name                        = "role1"
  backend                          = vault_kubernetes_auth_backend_config.config.backend
  bound_service_account_names      = ["default"]
  bound_service_account_namespaces = ["app"]
  token_policies                   = [vault_policy.dev.name]
  audience                         = "vault"
  token_ttl                        = "86400"
}

# K8s Static Auth + Static Secret 
resource "kubernetes_manifest" "static_auth" {

  manifest = {
    "apiVersion" = "secrets.hashicorp.com/v1beta1"
    "kind"       = "VaultAuth"
    "metadata" = {
      "name"      = "static-auth"
      "namespace" = "app"
    }
    "spec" = {
      "method" = "kubernetes"
      "mount"  = "demo-auth-mount"
      "kubernetes" = {
        "role"           = "role1"
        "serviceAccount" = "default"
        "audiences"      = ["vault"]
      }
    }
  }
}

# Declare Destination in k8s for static secret
resource "kubernetes_manifest" "vault_kv_app" {
  manifest = {
    "apiVersion" = "secrets.hashicorp.com/v1beta1"
    "kind"       = "VaultStaticSecret"
    "metadata" = {
      "name"      = "vault-kv-app"
      "namespace" = "app"
    }
    "spec" = {
      "type"  = "kv-v2"
      "mount" = "kvv2"
      "path"  = "webapp/config"
      "destination" = {
        "name"   = "secretkv"
        "create" = true
      }
      "refreshAfter" = "10s"
      "vaultAuthRef" = "static-auth"
    }
  }
}

# Dynamic Auth + Dynamic Secret
resource "kubernetes_manifest" "vso_db_demo" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultDynamicSecret"
    metadata = {
      name      = "vso-db-demo"
      namespace = "demo-ns"
    }
    spec = {
      mount = "demo-db"
      path  = "creds/${vault_database_secret_backend_role.dev_postgres.name}"
      destination = {
        create = false
        name   = "vso-db-demo"
      }
      rolloutRestartTargets = [
        {
          kind = "Deployment"
          name = "vso-db-demo"
        }
      ]
      vaultAuthRef = "dynamic-auth"
    }
  }
}

resource "kubernetes_manifest" "dynamic_auth" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "dynamic-auth"
      namespace = "demo-ns"
    }
    spec = {
      method = "kubernetes"
      mount  = "demo-auth-mount"
      kubernetes = {
        role           = "auth-role"
        serviceAccount = "default"
        audiences      = ["vault"]
      }
    }
  }
}

resource "kubernetes_secret" "vso_db_demo" {
  metadata {
    name      = "vso-db-demo"
    namespace = kubernetes_namespace.demo_ns.metadata[0].name
  }
}


# TLS Auth
resource "kubernetes_manifest" "tls_auth" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "tls-auth"
      namespace = "nginx"
    }
    spec = {
      method = "kubernetes"
      mount  = "demo-auth-mount"
      kubernetes = {
        role           = "tls"
        serviceAccount = "default"
        audiences      = ["vault"]
      }
    }
  }
}

# Transit Auth 
resource "kubernetes_manifest" "transit_auth" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "transit-auth"
      namespace = "vault-secrets-operator-system"
      labels = {
        cacheStorageEncryption = "true"
      }
    }
    spec = {
      method             = "kubernetes"
      mount              = "demo-auth-mount"
      vaultConnectionRef = "dynamic-auth"
      kubernetes = {
        role           = "auth-role-operator"
        serviceAccount = "default"
        audiences      = ["vault"]
      }
      storageEncryption = {
        mount   = "demo-transit"
        keyName = "vso-client-cache"
      }
    }
  }
}
