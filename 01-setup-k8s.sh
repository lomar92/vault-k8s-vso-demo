#!/bin/bash

## Deploy Vault in K8s via TF 
cd vault && terraform init 
terraform apply --auto-approve

kubectl wait --timeout=60s --for=jsonpath='{.status.phase}'=Running --namespace vault po -l app.kubernetes.io/instance=vault
kubectl port-forward --namespace=vault service/vault 8200:8200 &

## Install Vault VSO CRD
kubectl delete ns vault-secrets-operator-system
kubectl create ns vault-secrets-operator-system
helm uninstall vault-secrets-operator -n vault-secrets-operator-system
helm install vault-secrets-operator hashicorp/vault-secrets-operator --version 0.8.1 -n vault-secrets-operator-system --values vault-operator-values.yaml --wait

## Deploy Postgres via Helm 
kubectl delete ns postgres
kubectl create ns postgres
helm uninstall postgres -n postgres
helm upgrade --install postgres oci://registry-1.docker.io/bitnamicharts/postgresql --namespace postgres --set auth.audit.logConnections=true --set auth.postgresPassword=secret-pass --wait

kubectl wait --timeout=60s --for=jsonpath='{.status.phase}'=Running --namespace postgres po -l app.kubernetes.io/instance=postgres
kubectl port-forward --namespace=postgres service/postgres-postgresql 5432:5432 &

cd ../k8s && terraform init 
terraform apply --auto-approve

# view k8s ressources
kubectl get ns
kubectl get pods -n vault 
kubectl get pods -n vault-secrets-operator-system
kubectl get pods -n postgres
kubectl get pods -n demo-ns 
kubectl get pods -n nginx

# view k8s secrets 
kubectl get secrets -n app # static
kubectl get secrets -n demo-ns # dynamic
kubectl get secrets -n nginx # pki cert
