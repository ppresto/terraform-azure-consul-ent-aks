#!/bin/bash

# Source this file to export Consul address and cert into the local shell environment.
# Example:  
# $ source ./setup.sh

# connect to primary cluster
kubectl config use-context consul0

kubectl get secret --namespace consul consul-server-cert -o jsonpath="{.data['tls\.crt']}" | base64 --decode > ca.pem

export CONSUL_CACERT=ca.pem
export CONSUL_HTTP_TOKEN=$(kubectl get --namespace consul secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)

# using kubectl to run consul commands with anonymous access
kubectl -n consul exec -it consul-server-0 -- consul members

# consul command to list partitions that requires ACL token
kubectl -n consul exec -it consul-server-0 -- consul partition list -token "${CONSUL_HTTP_TOKEN}"
# list auth methods
kubectl -n consul exec -it consul-server-0 -- consul acl auth-method list -token ${CONSUL_HTTP_TOKEN}