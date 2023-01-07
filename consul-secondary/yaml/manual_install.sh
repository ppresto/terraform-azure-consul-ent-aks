#!/bin/bash

#export VERSION=0.41.1
export VERSION=1.0.2

# PreReq - 
#  Setup Kubeconfig to auth into AKS Consul cluster
#  k8s contexts are: consul0, consul1, aks0, aks1
export CONTEXT="aks0"

kubectl config use-context ${CONTEXT}

# Setup helm chart repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm search repo hashicorp/consul

# Verify consul namespace doesn't exist and create it.
kubectl get namespace --context ${CONTEXT}

kubectl create ns consul --context ${CONTEXT}

# Copy federation and license secrets from primary to the secondary
kubectl -n consul get secret consul-federation --context consul0 -o yaml | kubectl apply --context ${CONTEXT} -f -
kubectl -n consul get secret consul-ent-license --context consul0 -o yaml | kubectl apply --context ${CONTEXT} -f -


# Install consul helm chart with custom values
# Examples:
# helm install aks0-consul hashicorp/consul --version "0.41.1" --namespace consul --values aks0-values.yaml
# helm install aks1-consul hashicorp/consul --version "0.41.1" --namespace consul --values aks1-values.yaml
#
echo "Installing consul helm chart ${VERSION} ..."
helm install ${CONTEXT}-consul hashicorp/consul --version ${VERSION} --namespace consul --values yaml/auto-${CONTEXT}-values.yaml

# Uninstall using consul-k8s CLI
# consul-k8s uninstall -auto-approve -wipe-data

# Helm example, but not as clean as consul-k8s
# helm -n ${CONTEXT}-consul uninstall consul