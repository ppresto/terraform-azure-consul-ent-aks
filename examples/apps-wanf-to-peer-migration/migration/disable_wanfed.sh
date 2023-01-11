#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

function replication_hc () {
    kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/acl/replication | jq -r
}


function forceLeaveNodes () {
    nodes=$(kubectl -n consul exec -it consul-server-0 -- consul catalog nodes -service consul | awk '{ print $1 }'| tail -n +2)
    leader=$(kubectl -n consul exec -it consul-server-0 -- curl -k --request GET https://localhost:8501/v1/status/leader | sed s/\"//g | cut -d: -f1)
    
    for node in $nodes
    do
        echo
        echo "${node} - Removing ..."
        kubectl config use-context consul1
        kubectl -n consul exec -it consul-server-0 -- consul force-leave -token="${CONSUL_HTTP_TOKEN}" -wan -prune ${node}.consul1-westus2
        kubectl exec statefulset/consul-server --namespace consul -- consul members -wan
        sleep 2
        kubectl config use-context consul0
        kubectl -n consul exec -it consul-server-0 -- consul force-leave -token="${CONSUL_HTTP_TOKEN}" -wan -prune ${node}.consul1-westus2
        kubectl exec statefulset/consul-server --namespace consul -- consul members -wan
    done
}

#
# main
#
kubectl config use-context consul0
export CONSUL_HTTP_TOKEN=$(kubectl -n consul get secrets consul-bootstrap-acl-token -o go-template --template="{{.data.token|base64decode}}")

forceLeaveNodes
