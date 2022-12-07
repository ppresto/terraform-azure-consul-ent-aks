#!/bin/bash

deploy() {
    # deploy eastus services
    kubectl config use-context aks0
    kubectl apply -f eastus/eastus-1/init-consul-config
    kubectl apply -f eastus/eastus-1/release-api

    # deploy westus2 services
    kubectl config use-context aks1
    kubectl apply -f westus2/init-consul-config
    kubectl apply -f westus2/westus2-1

    # Output Ingress URL for fake-service
    echo "http://$(kc get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].ip'):8080/ui"
    
}

delete() {
    kubectl config use-context aks0
    kubectl delete -f eastus/eastus-1/release-api
    kubectl delete -f eastus/eastus-1/init-consul-config
    kubectl config use-context aks1
    kubectl delete -f westus2/westus2-1
    kubectl delete -f westus2/init-consul-config

}
#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi