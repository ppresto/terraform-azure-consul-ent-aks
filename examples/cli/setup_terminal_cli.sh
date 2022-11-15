#!/bin/bash

# Source this file to export Consul address and cert into the local shell environment.
# Example:  
# $ source ./setup.sh

# connect to primary cluster
kubectl config use-context consul0

kubectl port-forward --namespace consul consul-server-0 8501:8501 &
sleep 3

kubectl get secret --namespace consul consul-server-cert -o jsonpath="{.data['tls\.crt']}" | base64 --decode > ca.pem

export CONSUL_HTTP_ADDR=https://127.0.0.1:8501
export CONSUL_CACERT=ca.pem
export CONSUL_HTTP_TOKEN=$(kubectl get --namespace consul secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)

consul members
consul members -wan

# clean up
pkill kubectl
rm ca.pem

