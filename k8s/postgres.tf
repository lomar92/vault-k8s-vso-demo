# Bereitstellen der PostgreSQL-Datenbank erfolgt Helm

## Vault Configuration 
# Enable & Configure Postgres
resource "vault_mount" "postgres" {
  path        = "demo-db"
  type        = "database"
  description = "Datenbank credentials for postgres"
}

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_mount.postgres.path
  name          = "demo-db"
  plugin_name   = "postgresql-database-plugin"
  allowed_roles = ["dev-postgres"]
  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@postgres-postgresql.postgres.svc.cluster.local:5432/postgres?sslmode=disable"

    username             = var.postgres_username
    password             = var.postgres_password
    max_open_connections = 4
  }

}

# Create Postgres Role
resource "vault_database_secret_backend_role" "dev_postgres" {
  backend = vault_mount.postgres.path
  name    = "dev-postgres"
  db_name = vault_database_secret_backend_connection.postgres.name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT ALL PRIVILEGES ON DATABASE postgres TO \"{{name}}\";"
  ]

  default_ttl = "120"
  max_ttl     = "120"
}

# Policy for Operator
resource "vault_policy" "demo_auth_policy_db" {
  name   = "demo-auth-policy-db"
  policy = <<EOT
path "demo-db/creds/dev-postgres" {
   capabilities = ["read"]
}
EOT
}


# k8s role for dynamic db creds 
resource "vault_kubernetes_auth_backend_role" "auth_role" {
  backend                          = vault_auth_backend.default.path
  role_name                        = "auth-role"
  bound_service_account_names      = ["default"]
  bound_service_account_namespaces = [kubernetes_namespace.demo_ns.metadata[0].name]
  token_ttl                        = 0
  token_period                     = 120
  token_policies                   = [vault_policy.demo_auth_policy_db.name]
  audience                         = "vault"
}

# App Deployment with mounted secret
resource "kubernetes_deployment" "vso_db_demo" {
  depends_on = [kubernetes_secret.vso_db_demo]
  metadata {
    name      = "vso-db-demo"
    namespace = kubernetes_namespace.demo_ns.metadata[0].name
    labels = {
      test = "vso-db-demo"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        test = "vso-db-demo"
      }
    }

    strategy {
      rolling_update {
        max_unavailable = 1
      }
    }

    template {
      metadata {
        labels = {
          test = "vso-db-demo"
        }
      }

      spec {
        container {
          name  = "example"
          image = "nginx:latest"

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = "vso-db-demo"
                key  = "password"
              }
            }
          }

          env {
            name = "DB_USERNAME"
            value_from {
              secret_key_ref {
                name = "vso-db-demo"
                key  = "username"
              }
            }
          }

          volume_mount {
            name       = "secrets"
            mount_path = "/etc/secrets"
            read_only  = true
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }

            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
              http_header {
                name  = "X-Custom-Header"
                value = "Awesome"
              }
            }

            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }

        volume {
          name = "secrets"

          secret {
            secret_name = "vso-db-demo"
          }
        }
      }
    }
  }
}
