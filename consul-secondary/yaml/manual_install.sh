#!/bin/bash

export VERSION=0.41.1

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

# Copy federation and license secrets from consul0 to the secondary
kubectl -n consul get secret consul-federation --context consul0 -o yaml | kubectl apply --context ${CONTEXT} -f -
kubectl -n consul get secret consul-ent-license --context consul0 -o yaml | kubectl apply --context ${CONTEXT} -f -


# Install consul helm chart with custom values
# Examples:
# helm install aks0-consul hashicorp/consul --version "0.41.1" --namespace consul --values aks0-values.yaml
# helm install aks1-consul hashicorp/consul --version "0.41.1" --namespace consul --values aks1-values.yaml
#
echo "Installing consul helm chart ${VERSION} ..."
helm install ${CONTEXT}-consul hashicorp/consul --version ${VERSION} --namespace consul --values ${CONTEXT}-values.yaml

# Uninstall
# helm -n ${CONTEXT}-consul uninstall consul