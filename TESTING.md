# Testing Config Order

## Get Consul UI
```
examples/ui/get_consul0_ui_url.sh  # Datacenter consul0-eastus
examples/ui/get_consul1_ui_url.sh  # Datacenter consul1-westus2
```

## Apply mesh defaults first.
```
consul0
kubectl apply -f examples/apps-server-default-default/fake-service/eastus/init-consul-config/mesh.yaml
consul1
kubectl apply -f examples/apps-server-default-default/fake-service/westus2/init-consul-config/mesh.yaml
```

## Peer Clusters (this sets up service exports too)
```
cd examples/apps-server-default-default/peering/
./peer_consul0_to_consul1.sh
cd ../../..
```

## Apply proxy-defaults, service defaults.
```
consul0
kubectl apply -f examples/apps-server-default-default/fake-service/eastus/init-consul-config/proxydefaults.yaml
kubectl apply -f examples/apps-server-default-default/fake-service/eastus/init-consul-config/servicedefaults.yaml
consul1
kubectl apply -f examples/apps-server-default-default/fake-service/westus2/init-consul-config/proxydefaults.yaml
kubectl apply -f examples/apps-server-default-default/fake-service/westus2/init-consul-config/servicedefaults.yaml
```

## Deploy Services
```
kubectl config use-context consul0
kubectl apply -f examples/apps-server-default-default/fake-service/eastus/

kubectl config use-context consul1
kubectl apply -f examples/apps-server-default-default/fake-service/westus2/
```

## Deploy Exports (already done in peering script)
```
```

## Deploy Intentions and IGW to access fake-service
```
consul0
kubectl apply -f examples/apps-server-default-default/fake-service/eastus/init-consul-config/intentions-api.yaml
kubectl apply -f examples/apps-server-default-default/fake-service/eastus/init-consul-config/intentions-web.yaml
consul1
kubectl apply -f examples/apps-server-default-default/fake-service/westus2/init-consul-config/intentions-api.yaml
kubectl apply -f examples/apps-server-default-default/fake-service/westus2/init-consul-config/intentions-web.yaml
kubectl apply -f examples/apps-server-default-default/fake-service/westus2/init-consul-config/ingressGW.yaml
```

## Get Fake Service URL (westus2/default/default/web --> eastus/default/default/api)
```
consul1
echo "http://$(kubectl -n consul get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].ip'):8080/ui"
```
Review `examples/apps-server-default-default/fake-service/westus2/web.yaml` to verify static upstream config points to peer.


## Get Fake Service Pod IP's
Verify the `api` pod IP `web` is routing too.
```
consul0
kubectl get pods -o wide -l app=api

consul1
kubectl get pods -o wide -l app=api
```

## Lookup Service Discovery Chain

### westus2 - verify protocols are http and mesh gateway is local
```
# use-context for westus2 consul cluster
consul1

export CONSUL_HTTP_TOKEN=$(kubectl get --namespace consul secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)

kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/discovery-chain/api | jq -r

kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/discovery-chain/web | jq -r
```

### Peer Endpoint (api) should point to the MG on the other side
```
kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/health/connect/api?peer=consul0-eastus | jq -r
```


