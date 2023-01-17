#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

function dns() {
# DNS
cat <<EOF | kubectl -n consul exec -it consul-server-0 -- consul acl policy create -token "${CONSUL_HTTP_TOKEN}" -name "dns-requests" -rules -
node_prefix "" {
  policy = "read"
}
service_prefix "" {
  policy = "read"
}
EOF
export dnsrequest_token=$(kubectl -n consul exec -it consul-server-0 -- consul acl token create -token "${CONSUL_HTTP_TOKEN}" -description "All DNS Requests" -policy-name dns-requests -format=json | jq -r '.SecretID')
kubectl -n consul exec -it consul-server-0 -- consul acl set-agent-token -token "${CONSUL_HTTP_TOKEN}" default "${dnsrequest_token}"
}

function ui (){
# UI
cat <<EOF | kubectl -n consul exec -it consul-server-0 -- consul acl policy create -token "${CONSUL_HTTP_TOKEN}" -name "ui-read" -rules -
service_prefix "" {
  policy = "read"
}
key_prefix "" {
  policy = "read"
}
node_prefix "" {
  policy = "read"
}
acl "" {
  policy = "read"
}
EOF
export ui_token=$(kubectl -n consul exec -it consul-server-0 -- consul acl token create -token "${CONSUL_HTTP_TOKEN}" -description "UI Read Access" -policy-name ui-read -format=json | jq -r '.SecretID')
echo "UI Token: ${ui_token}"
}

function kv () {
# KV
cat <<EOF | kubectl -n consul exec -it consul-server-0 -- consul acl policy create -token "${CONSUL_HTTP_TOKEN}" -name "kv-admin" -rules -
namespace_prefix "" {
    key_prefix "" {
        policy = "write"
    }
    service_prefix "" {
        policy = "read"
    }
    node_prefix "" {
        policy = "read"
    }
}
EOF
export kv_token=$(kubectl -n consul exec -it consul-server-0 -- consul acl token create -token "${CONSUL_HTTP_TOKEN}" -description "KV Management" -policy-name kv-admin -format=json | jq -r '.SecretID')
}

function kv_write () {
    echo
    echo "Creating KV for $(kubectl config current-context)"
    echo "Using Token: ${kv_token}"
    kubectl -n consul exec -it consul-server-0 -- consul kv put -token "${kv_token}" wan/test "$(kubectl config current-context)-data"
    echo "Reading KV Data..."
    kubectl -n consul exec -it consul-server-0 -- consul kv get -token "${kv_token}" wan/test
    echo
}

function replication_hc () {
    kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/acl/replication | jq -r
}

function getNodes () {
    echo "$(kubectl -n consul exec -it consul-server-0 -- consul catalog nodes -service consul)"
    echo "Leader: $(kubectl -n consul exec -it consul-server-0 -- curl -k --request GET https://localhost:8501/v1/status/leader)"

}
kubectl config use-context consul0
export CONSUL_HTTP_TOKEN=$(kubectl -n consul get secrets consul-bootstrap-acl-token -o go-template --template="{{.data.token|base64decode}}")

#
# main
#

# Create Primary Policies, Tokens, K/V
dns
ui
kv
kv_write

# Create Secondary K/V
kubectl config use-context consul1
kv_write

# Validate Secondary Replication Status
replication_hc

# Get Nodes and identify leader
getNodes