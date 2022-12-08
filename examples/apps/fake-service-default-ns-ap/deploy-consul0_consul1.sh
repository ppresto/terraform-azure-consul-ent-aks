#!/bin/bash

deploy() {
    # deploy eastus services
    kubectl config use-context consul0
    kubectl apply -f eastus/init-consul-config
    kubectl apply -f eastus/

    # deploy westus2 services
    kubectl config use-context consul1
    kubectl apply -f westus2/init-consul-config
    kubectl apply -f westus2/

    # Output Ingress URL for fake-service
    echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].ip'):8080/ui"
}

delete() {
    kubectl config use-context consul0
    kubectl delete -f eastus/
    kubectl delete -f eastus/init-consul-config
    kubectl config use-context consul1
    kubectl delete -f westus2/
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