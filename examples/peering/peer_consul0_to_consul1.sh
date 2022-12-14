#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)
# PreReq - 
#  Setup Kubeconfig to auth into AKS Consul cluster

function setup () {
  #kubectl config use-context consul0
  kubectl config use-context consul0

  # Create Peering Acceptor (consul0)
  kubectl apply -f ${SCRIPT_DIR}/peering-acceptor-consul0.yaml

  # Verify Peering Acceptor and Secret was created
  kubectl -n consul get secrets peering-token-consul1-westus2
  kubectl -n consul get peeringacceptors

  # Copy secrets from peering acceptor (consul0) to peering dialer (consul1)
  kubectl -n consul get secret peering-token-consul1-westus2 --context consul0 -o yaml | kubectl apply --context consul1 -f -

  # Create Peering Dialer (consul1)
  kubectl config use-context consul1
  kubectl apply -f ${SCRIPT_DIR}/peering-dialer-consul1.yaml

  # Verify peering on consul0
  kubectl config use-context consul0
  echo
  echo "Verifying Peering Connection on Acceptor (consul0) with curl command:"
  echo "kubectl -n consul exec -it consul-server-0 -- curl -k --header \"X-Consul-Token: ${CONSUL_HTTP_TOKEN}\" --request GET https://localhost:8501/v1/peering/consul1-westus2"
  sleep 5
  CONSUL_HTTP_TOKEN=$(kubectl -n consul get secrets consul-bootstrap-acl-token -o go-template --template="{{.data.token|base64decode}}")
  kubectl -n consul exec -it consul-server-0 -- curl -k \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --request GET \
      https://localhost:8501/v1/peering/consul1-westus2 \
      | jq -r

  # Export Services for each peer to advertise available service catalog.
  echo "Exporting Acceptor services..."
  kubectl config use-context consul0
  kubectl apply -f ${SCRIPT_DIR}/exportedServices_consul0-eastus.yaml
  echo "Exporting Dialer services..."
  kubectl config use-context consul1
  kubectl apply -f ${SCRIPT_DIR}/exportedServices_consul1-westus2.yaml
}

# Clean up
function remove () {
    kubectl config use-context consul1
    kubectl delete -f ${SCRIPT_DIR}/exportedServices_consul1-westus2.yaml
    kubectl delete -f ${SCRIPT_DIR}/peering-dialer-consul1.yaml
    kubectl -n consul delete secret peering-token-consul1-westus2

    kubectl config use-context consul0
    kubectl delete -f ${SCRIPT_DIR}/exportedServices_consul0-eastus.yaml
    kubectl delete -f ${SCRIPT_DIR}/peering-acceptor-consul0.yaml
}

#setup
remove