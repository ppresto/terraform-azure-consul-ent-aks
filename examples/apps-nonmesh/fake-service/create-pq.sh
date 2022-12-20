kubectl config use-context consul1

export CONSUL_HTTP_TOKEN=$(kubectl get --namespace consul secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)

function createDynamic {
    kubectl -n consul exec -it consul-server-0 -- curl -kv \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --request POST \
      https://localhost:8501/v1/query \
      --data @- << 'EOF'
{
  "Name": "",
  "Template": {
    "Type": "name_prefix_match"
  },
  "Service": {
    "Service": "${name.full}-ha",
    "Failover": {
      "Targets": [
        {"Peer": "consul0-eastus"}
      ]
    }
  }
}
EOF
}

function createStatic {
    kubectl -n consul exec -it consul-server-0 -- curl -kv \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --request POST \
      https://localhost:8501/v1/query \
      --data @- << EOF
{
    "Name": "api-ha",
    "Service": {
        "Service": "api",
        "Namespace": "default",
        "Tags": ["k8s"],
        "Failover": {
            "Targets": [{"Peer": "consul0-eastus"}]
        }
    }
}
EOF
}

function create {
    kubectl -n consul exec -it consul-server-0 -- curl -kv \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --request POST \
      https://localhost:8501/v1/query \
      --data @- << 'EOF'
{
  "Name": "",
  "Template": {
    "Type": "name_prefix_match",
    "Regexp": "(.*)-ha"
  },
  "Service": {
    "Service": "${match(1)}",
    "Failover": {
      "Targets": [
        {"Peer": "consul0-eastus"}
      ]
    }
  }
}
EOF
}

function delete {
    kubectl -n consul exec -it consul-server-0 -- curl -kv \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      --request DELETE \
      "https://localhost:8501/v1/query/${1}"
}

function list {
    kubectl -n consul exec -it consul-server-0 -- curl -k \
      --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" \
      https://localhost:8501/v1/query \
      | jq -r
}

if [[ -z $1 ]]; then
    create
    #createDynamic
elif [[ "${1}" == "delete" ]]; then
    # list pq to get UUID and pass this on the CLI after 'delete'
    delete "${2}"
elif [[ ! -z "${1}" ]]; then
    ${1}
fi