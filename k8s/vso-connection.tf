# Deployment VSO erfolgt per Helm Chart

resource "kubernetes_service_account" "demo_operator" {
  metadata {
    name      = "demo-operator"
    namespace = "vault-secrets-operator-system"
  }
}



# Enable Transit Ecnryption for Operator / Client Cache 
## https://developer.hashicorp.com/vault/tutorials/kubernetes/vault-secrets-operator#transit-encryption

resource "vault_mount" "demo_transit" {
  path        = "demo-transit"
  type        = "transit"
  description = "Transit secrets engine for VSO"
}

resource "vault_transit_secret_backend_key" "vso_client_cache" {
  backend          = vault_mount.demo_transit.path
  name             = "vso-client-cache"
  type             = "aes256-gcm96"
  deletion_allowed = "true"
}


# Policy for Operator
resource "vault_policy" "demo_auth_policy_operator" {
  name   = "demo-auth-policy-operator"
  policy = <<EOT
path "demo-transit/encrypt/vso-client-cache" {
   capabilities = ["create", "update"]
}
path "demo-transit/decrypt/vso-client-cache" {
   capabilities = ["create", "update"]
}
EOT
}

# Create DB Role Transit
resource "vault_kubernetes_auth_backend_role" "auth_role_operator" {
  backend                          = vault_auth_backend.default.path
  role_name                        = "auth-role-operator"
  bound_service_account_names      = [kubernetes_service_account.demo_operator.metadata[0].name]
  bound_service_account_namespaces = ["vault-secrets-operator-system"]
  token_ttl                        = 0
  token_period                     = 120
  token_policies                   = [vault_policy.demo_auth_policy_db.name]
  audience                         = "vault"
}
