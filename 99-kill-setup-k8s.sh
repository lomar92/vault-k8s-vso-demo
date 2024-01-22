#!/bin/bash

## Destroy Vault and k8s ressoures via TF 
cd k8s && terraform destroy --auto-approve

sleep 10

cd ../vault && terraform destroy --auto-approve


sleep 10 

kubectl delete ns vault

## Uninstall Vault VSO CRD
helm uninstall vault-secrets-operator -n vault-secrets-operator-system
kubectl delete ns vault-secrets-operator-system

sleep 10

## Uninstall Postgres via Helm 
helm uninstall postgres -n postgres
kubectl delete ns postgres

sleep 10

## remove tf state file
rm terraform.tfstate
rm terraform.tfstate.backup
rm terraform.lock.hcl
rm .terraform.lock.hcl


cd ../k8s && rm .terraform.lock.hcl
rm terraform.tfstate
rm terraform.tfstate.backup

cd ../
rm pod-cert.crt
rm tls-cert.crt
rm tls.crt
rm static-secret.yml