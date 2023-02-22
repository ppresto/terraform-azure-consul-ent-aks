# Custom Partition Peering on AKS dataplane

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

## Configure default partition
default partition manages the mesh defaults for other partitions.  Set this to peer through meshgateways.
```
consul0
kubectl apply -f ./examples/apps-peer-dataplane-ap-ns/fake-service/westus2/init-consul-config/mesh.yaml.disable
consul1
kubectl apply -f ./examples/apps-peer-dataplane-ap-ns/fake-service/westus2/init-consul-config/mesh.yaml.disable
```

## Deploy Services to test Failover
Deploy services to the East/West AKS dataplane clusters bootstrapped to Consul.
```
./examples/apps-peer-dataplane-ap-ns/fake-service/deploy-with-failover.sh
```
* Review Service Topology
* Get the application URL from the script output

Review Pod IP's in the 3 different Zones and verify westus2-1 is serving all traffic
```
aks1
kubectl get pods -o wide -l service=fake-service -A
```

## Setup Peering between partitions
```
./examples/apps-peer-dataplane-ap-ns/peering/peer_aks0_to_aks1.sh
```
Review Peering and Services in UI

## Review Failover with a [Service-Resolver](https://developer.hashicorp.com/consul/docs/connect/config-entries/service-resolver#filter-on-service-version)
```
aks1
kubectl apply -f ./examples/apps-peer-dataplane-ap-ns/fake-service/westus2/westus2-1/traffic-mgmt.yaml
```

In the UI (consul1-westus2) go to Services->api->routing and you should see the Peer failover target (consul0-eastus).  This means everything is setup for regional failover.  

## Failover validation
Delete the local api service running in westus2-1 to test zone 2 failover.
```
aks1
kubectl delete -f ./examples/apps-peer-dataplane-ap-ns/fake-service/westus2/westus2-1/api-westus2-1.yaml
kubectl get pods -o wide -l service=fake-service -A
```

Delete the local api service running in westus2-2 to test zone 3 failover.
```
aks1
kubectl delete -f ./examples/apps-peer-dataplane-ap-ns/fake-service/westus2/westus2-2/api-westus2-2.yaml
kubectl get pods -o wide -l service=fake-service -A
```

Delete the local api service running in westus2-3 to test peer failover (Not WORKING in 1.14.4)
```
aks1
kubectl delete -f ./examples/apps-peer-dataplane-ap-ns/fake-service/westus2/westus2-3/api-westus2-3.yaml
kubectl get pods -o wide -l service=fake-service -A
```

## Cleanup

```
./examples/apps-peer-dataplane-ap-ns/peering/peer_aks0_to_aks1.sh delete
./examples/apps-peer-dataplane-ap-ns/fake-service/deploy-with-failover.sh delete

consul0
kubectl delete -f ./examples/apps-peer-dataplane-ap-ns/fake-service/westus2/init-consul-config/mesh.yaml.disable

consul1
kubectl delete -f ./examples/apps-peer-dataplane-ap-ns/fake-service/westus2/init-consul-config/mesh.yaml.disable
```

### Forward Requests to Peer directly (No Failover - ServiceResolver)
* FYI: To route `web` from westus2-shared peer to eastus-shared peer for all requests (no failover) update the upstream for `web` to point directly to the eastus-shared peer's `api` service.
```
./examples/apps-peer-dataplane-ap-ns/fake-service/deploy-with-upstream.sh

annotations:
  consul.hashicorp.com/connect-service-upstreams: 'api.svc.eastus-1.ns.eastus-shared.peer:9091'
```

After successfully testing this use case delete the deployment and mesh configurations with the following command.
```
./examples/apps-peer-dataplane-ap-ns/fake-service/deploy-with-upstream.sh delete
```

## Troubleshoot Failover
Failover is configured using a ServiceResolver.  This was configured as part of the service deployment for the api service running in region westus2 and zone westus2-1 [westus2-1](./examples/apps-dataplane-partition-ns/fake-service/westus2/westus2-1/traffic-mgmt.yaml)

### Review Mesh gateway failover route from west to east
```
# Get MGW IP (West)
aks1
kubectl -n westus2-1 exec -it deploy/web -- curl localhost:19000/clusters


# Verify Local MGW IP
kc get po -o wide

#
kc port-forward deploy/aks1-mesh-gateway 19000:19000

# Review 
kc get svc
```

### Connect - Review Peer Failover Targets
Discovery Chain - verify protocols are all http
```
# use-context for westus2 consul cluster
consul1

export CONSUL_HTTP_TOKEN=$(kubectl get --namespace consul secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)

kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/discovery-chain/api | jq -r
```
Endpoint should point to the MG on the other side (not working)
```
kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/health/connect/api?namespace=eastus-1&peer=eastus-shared | jq -r