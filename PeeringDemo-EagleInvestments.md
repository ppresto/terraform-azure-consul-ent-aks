# Peering Demo

## Pre
* East/West Consul UI Browser Tabs
```
cd .. # Go to repo base
examples/ui/get_consul0_ui_url.sh  # Datacenter consul0-eastus
examples/ui/get_consul1_ui_url.sh  # Datacenter consul1-westus2
```
* open fake-service/westus2/init-consul-config/intentions-api.yaml.dis
* open peering-acceptor-consul0.yaml and dialer yaml
* open serviceresolver.yaml.dis


## Deploy Services to Consul's default partition and namespace
To simplify the design, deploy services directly to the East/West AKS clusters running Consul.
```
./examples/apps-peer-server-def-def-demo/fake-service/deploy-consul0_consul1.sh
```
* Review Service Topology to identify missing Intention (web/studio-ui) 
* Get the application URL from the script output and verify broken connection

Add the Intention and watch the UI turn green.
```
kubectl apply -f ./examples/apps-peer-server-def-def-demo/fake-service/westus2/init-consul-config/intentions-api.yaml.dis
```
Verify the appication is accepting requests.

After verifying the service URL is healthy, refresh a couple times and pay attention to the IP Addresses serving `svc-studio-query` from westus2 region. Use the CLI to verify the pod IP Addresses running `svc-studio-query` in westus2.
```
consul1
kubectl get pods -o wide -l service=fake-service
```

## Setup Peering
```
./examples/apps-peer-server-def-def-demo/peering/peer_consul0_to_consul1.sh
```
Review Peering and Services in UI

## Setup Failover with a [Service-Resolver](https://developer.hashicorp.com/consul/docs/connect/config-entries/service-resolver#filter-on-service-version)
Now that the two clusters are peered and running `svc-studio-query`, you can setup failover from westus2 to eastus.  

Switch to the westus2 cluster and apply the failover serviceresolver.
```
consul1
kubectl apply -f ./examples/apps-peer-server-def-def-demo/fake-service/westus2/serviceresolver.yaml.dis
```

In the UI (consul1-westus2) go to Services->api->routing and you should see the Peer failover target (consul0-eastus).  This means everything is setup for regional failover.  

## Failover
Delete the local api service running in westus2 to test failover.
```
consul1
kubectl delete -f ./examples/apps-peer-server-def-def-demo/fake-service/westus2/api.yaml
consul0
kubectl get pods -o wide -l service=fake-service
```

Jump to the eastus context to see `svc-studio-query` and review its IP's to verify all traffic is currently local to westus2 and not using these IP's.
```
consul0
kubectl get pods -o wide -l service=fake-service
```

Refresh the browser and `svc-studio-query` should still be responding, but from a different set of IP's.  These IP's are now coming from eastus.  This validates regional failover.  

To repeat this failover test re-deploy the service in the west.
```
consul1
kubectl apply -f ./examples/apps-peer-server-def-def-demo/fake-service/westus2/api.yaml
kubectl get pods -o wide -l service=fake-service
```

## Cleanup

```
consul1
kubectl delete -f ./examples/apps-peer-server-def-def-demo/fake-service/westus2/init-consul-config/intentions-api.yaml.dis
kubectl delete -f ./examples/apps-peer-server-def-def-demo/fake-service/westus2/serviceresolver.yaml.dis
./examples/apps-peer-server-def-def-demo/peering/peer_consul0_to_consul1.sh delete
./examples/apps-peer-server-def-def-demo/fake-service/deploy-consul0_consul1.sh delete

```
## Notes
* FYI: To route `ui-studio` from westus2 to eastus for all requests (no failover) update the upstream for `ui-studio` to point directly to the consul0-eastus peer's `svc-studio-query` service.
```
kubectl apply -f examples/apps-peer-server-def-def-demo/fake-service/westus2/web.yaml.remote

annotations:
  consul.hashicorp.com/connect-service-upstreams: 'api.svc.default.ns.consul0-eastus.peer:9091'
  #consul.hashicorp.com/connect-service-upstreams: 'api:9091'
```

After successfully testing this use case delete the deployment and mesh configurations with the following command.
```
fake-service/deploy-consul0_consul1.sh delete
```

## Setup Peering (eastus/westus2)
Peer consul0-eastus / consul1-westus2 Consul clusters allowing services to be shared across them.  This will be used for failover.
```
cd ../peering/
./peer_aks0_to_aks1.sh
```

## Test Failover
Failover is configured using a ServiceResolver.  This was configured as part of the service deployment for the api service running in region westus2 and zone westus2-1 [westus2-1](./examples/apps-dataplane-partition-ns/fake-service/westus2/westus2-1/traffic-mgmt.yaml)

### Review Mesh gateway failover route from west to east
```
# Get MGW IP (West)
consul1
kubectl exec -it deploy/ui-studio -- curl localhost:19000/clusters

# Verify Local MGW IP
kc get po -o wide

#
kc port-forward deploy/consul-mesh-gateway 19000:19000

# Review 
kc get svc
```

### Connect - Review Peer Failover Targets
Discovery Chain - verify protocols are all http
```
# use-context for westus2 consul cluster
consul1

export CONSUL_HTTP_TOKEN=$(kubectl get --namespace consul secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)

kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/discovery-chain/svc-studio-query | jq -r
```
Endpoint should point to the MG on the other side
```
kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/health/connect/svc-studio-query?peer=consul0-eastus | jq -r