# Certificate tls for nginx 

resource "vault_mount" "pki" {
  path        = "pki"
  type        = "pki"
  description = "NGINX PKI Backend"
}

resource "vault_pki_secret_backend_root_cert" "root_cert" {
  depends_on  = [vault_mount.pki]
  backend     = vault_mount.pki.path
  type        = "internal"
  common_name = "example.com"
  ttl         = "768h"
}

resource "vault_pki_secret_backend_config_urls" "config_urls" {
  depends_on = [vault_mount.pki]

  backend                 = vault_mount.pki.path
  issuing_certificates    = ["http://127.0.0.1:8200/v1/pki/ca"]
  crl_distribution_points = ["http://127.0.0.1:8200/v1/pki/crl"]
}

resource "vault_pki_secret_backend_role" "tls" {
  depends_on = [vault_mount.pki]

  backend          = vault_mount.pki.path
  name             = "tls"
  allowed_domains  = ["example.com", "localhost"]
  allow_subdomains = true
  max_ttl          = "259200" #72h
}


# TLS Policy 
resource "vault_policy" "tls_policy" {
  name   = "tls"
  policy = <<-EOT
    path "pki/*" {
      capabilities = ["read", "create", "update"]
    }
  EOT
}

resource "vault_kubernetes_auth_backend_role" "tls_role" {
  backend                          = vault_auth_backend.default.path
  role_name                        = "tls"
  bound_service_account_names      = ["default"]
  bound_service_account_namespaces = [kubernetes_namespace.nginx.metadata[0].name]
  token_policies                   = [vault_policy.tls_policy.name]
  token_ttl                        = "3600"
  audience                         = "vault"
}

# K8s TLS Sync Destination Namespace
resource "kubernetes_manifest" "vaultpkisecret_tls" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultPKISecret"
    metadata = {
      name      = "vaultpkisecret-tls"
      namespace = kubernetes_namespace.nginx.metadata[0].name
    }
    spec = {
      vaultAuthRef = "tls-auth"
      namespace    = kubernetes_namespace.nginx.metadata[0].name
      mount        = vault_mount.pki.path
      role         = "tls"
      destination = {
        create = true
        name   = "pki-tls"
        type   = "kubernetes.io/tls"
      }
      commonName   = "localhost"
      format       = "pem"
      revoke       = true
      clear        = true
      expiryOffset = "15s"
      ttl          = "60m"
      rolloutRestartTargets = [
        {
          kind = "Deployment"
          name = "nginx"
        }
      ]
    }
  }
}

# resource "kubernetes_secret" "pki_secret" {
#   metadata {
#     name      = "pki-tls"
#     namespace = kubernetes_namespace.nginx.metadata[0].name
#   }
# }

# TLS App NGINX Deployment for Rollout Restart
resource "kubernetes_deployment" "nginx_tls_app" {
  metadata {
    name      = "nginx-tls-app"
    namespace = kubernetes_namespace.nginx.metadata[0].name
    labels = {
      app = "nginx-tls-app"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx-tls-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx-tls-app"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"

          port {
            container_port = 443
          }

          volume_mount {
            name       = "tls-volume"
            mount_path = "/etc/nginx/ssl"
            read_only  = true
          }

          volume_mount {
            name       = "nginx-conf"
            mount_path = "/etc/nginx/conf.d"
          }
        }

        volume {
          name = "tls-volume"

          secret {
            secret_name = "pki-tls"
          }
        }

        volume {
          name = "nginx-conf"

          config_map {
            name = "nginx-tls-conf"
          }
        }
      }
    }
  }
}

resource "kubernetes_config_map" "nginx_tls_conf" {
  metadata {
    name      = "nginx-tls-conf"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  data = {
    "default.conf" = <<-EOT
      server {
        listen 443 ssl;
        ssl_certificate /etc/nginx/ssl/tls.crt;
        ssl_certificate_key /etc/nginx/ssl/tls.key;

        location / {
          root   /usr/share/nginx/html;
          index  index.html index.htm;
        }
      }
    EOT
  }
}

resource "kubernetes_service" "nginx_tls_app_service" {
  metadata {
    name      = "nginx-tls-app-service"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  spec {
    selector = {
      app = "nginx-tls-app"
    }

    port {
      port        = 443
      target_port = 443
      node_port   = 30443
    }

    type = "NodePort"
  }
}


# TLS App NGINX Pod 
# resource "kubernetes_pod" "nginx_tls_app" {
#   metadata {
#     name      = "nginx-tls-app"
#     namespace = kubernetes_namespace.nginx.metadata[0].name
#     labels = {
#       app = "nginx-tls-app"
#     }
#   }

#   spec {
#     container {
#       image = "nginx:latest"
#       name  = "nginx"

#       port {
#         container_port = 443
#       }

#       volume_mount {
#         name       = "tls-volume"
#         mount_path = "/etc/nginx/ssl"
#         read_only  = true
#       }

#       volume_mount {
#         name       = "nginx-conf"
#         mount_path = "/etc/nginx/conf.d"
#       }
#     }

#     volume {
#       name = "tls-volume"

#       secret {
#         secret_name = "pki-tls"
#       }
#     }

#     volume {
#       name = "nginx-conf"

#       config_map {
#         name = "nginx-tls-conf"
#       }
#     }
#   }
# }
