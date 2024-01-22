#!/bin/bash

## Deploy Vault in K8s via TF 
cd vault && terraform init 
terraform apply --auto-approve

sleep 10

## Install Vault VSO CRD
kubectl delete ns vault-secrets-operator-system
kubectl create ns vault-secrets-operator-system
helm uninstall vault-secrets-operator -n vault-secrets-operator-system
helm install vault-secrets-operator hashicorp/vault-secrets-operator --version 0.4.3 -n vault-secrets-operator-system --values vault-operator-values.yaml

sleep 10

## Deploy Postgres via Helm 
kubectl delete ns postgres
kubectl create ns postgres
helm uninstall postgres -n postgres
helm upgrade --install postgres bitnami/postgresql --namespace postgres --set auth.audit.logConnections=true  --set auth.postgresPassword=secret-pass

sleep 30

cd ../k8s && terraform init 
terraform apply --auto-approve

# view k8s ressources
kubectl get ns
kubectl get pods -n vault 
kubectl get pods -n vault-secrets-operator
kubectl get pods -n postgres
kubectl get pods -n demo-ns 
kubectl get pods -n nginx

# view k8s secrets 
kubectl get secrets -n app # static
kubectl get secrets -n demo-ns # dynamic
kubectl get secrets -n nginx # pki cert