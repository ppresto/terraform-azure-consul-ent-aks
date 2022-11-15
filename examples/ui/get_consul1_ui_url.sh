#!/bin/bash

# Source this file to export Consul address and cert into the local shell environment.
# Example:  
# $ source ./setup.sh

# connect to primary/peer cluster
kubectl config use-context consul1
UI_URL=$(kubectl -n consul get svc consul-ui -o json | jq -r '.status.loadBalancer.ingress[].ip')
export CONSUL_HTTP_TOKEN=$(kubectl -n consul get secrets consul-bootstrap-acl-token -o go-template --template="{{.data.token|base64decode}}")

if [[ -z UI_URL ]]; then
    kubectl port-forward --namespace consul service/consul-ui 9000:443 &
    sleep 3
    echo
    echo "Consul UI: https://localhost:9000"
    echo
    echo "WARNING port 9000 is being used by kubectl port-forward to create this URL"
    echo "Kill this process after you are done to free up port 9000."
    echo "$ pkill kubectl"
    echo
else
    echo
    echo "Consul UI: https://${UI_URL}"
    echo
fi

echo "UI Token: ${CONSUL_HTTP_TOKEN}"