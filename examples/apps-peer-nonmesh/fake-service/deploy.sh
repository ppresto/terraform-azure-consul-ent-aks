#!/bin/bash

deploy() {
    echo "deploying services ..."
    # deploy eastus services
    kubectl config use-context consul0
    kubectl apply -f eastus/
    
    # deploy westus2 services
    kubectl config use-context consul1
    kubectl apply -f westus2/

    sleep 10
    # Output Fake-service loadBalancer URLs
    kubectl config use-context consul0
    echo
    echo "eastus-1  - http://$(kubectl -n default get svc web -o json | jq -r '.status.loadBalancer.ingress[].ip'):9090/ui"
    echo
    kubectl config use-context consul1
    echo
    echo "westus2-1 - http://$(kubectl -n default get svc web -o json | jq -r '.status.loadBalancer.ingress[].ip'):9090/ui"
    echo
}

delete() {
    kubectl config use-context consul0
    kubectl delete -f eastus/
    kubectl config use-context consul1
    kubectl delete -f westus2/
}
#Cleanup if any param is given on CLI
if [[ ! -z $1 ]]; then
    echo "Deleting Services"
    delete
else
    echo "Deploying Services"
    deploy
fi