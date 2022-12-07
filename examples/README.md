# Examples
Includes scripts that show how to setup the UI, CLI, deploy sample apps, and other consul configurations.
```
cd examples
```
## ./cli
Setup the command line environment to work with ACLs enabled
```
cli/setup.sh
```
## ./dns
Example `dns/coredns-custom.yaml` used to setup Consul DNS forwarding in Azure AKS.  Refer to ../README.md to use this file and quickly setup DNS Forwarding for your AKS cluster.
## ./ui
This script will output the URL and privilaged login token to provide you full admin access to the UI.  Once in the UI click on the `Log In` link and paste the token for full access. Review Services, Nodes, and the Consul datacenter drop down menu on the upper left.
```
ui/get_consul0_ui_url.sh
ui/get_consul1_ui_url.sh
```

## ./apps
[Fake Service](https://github.com/nicholasjackson/fake-service) is a test service that can handle both HTTP and gRPC traffic, for testing upstream service communications and other service mesh scenarios.  This service can be used to complete the following use cases.

### Use Case 1 - Services Isolated by Zone, Failover across Zones
Deploy a service stack in two different availability zones.  Services should only make inner zone calls to the other services in their stack.  Setup a failover rule so in the event a local service isn't available it will attempt to make a request to another AZ hosting a healthy instance of that service.

#### Setup Use Case 1

```
aks1  #Switch to westus2 app cluster context
kubectl apply -f apps/fake-service/westus2/init-consul-config
```

Deploy `web` and `api` services to the AKS services cluster `aks1` running in the secondary region (westus2).  These services will be deployed to a kubernetes namespace called westus2-1 which maps to the region and availability zone 1.  Once deployed to this k8s namespace consul will create a new consul namespace called 'westus2-1'.  This is enabled by the consul helm chart value `consulNamespaces:mirroringK8S`.  The service deployment files below will target only nodes in availability zone 1 (westus2-1) and run in kubernetes namespace `westus2-1`.
```
kubectl apply -f apps/fake-service/westus2/westus2-1/
kw1 get pods   # kw1 alias = kubectl -n westus2-1
```

Verify the `ingress-gateway` is routing external traffic to the `web`  pods.  `web` should be loadbalancing requests across the `api` pods.
```
echo "http://$(kc get svc -l component=ingress-gateway -o json | jq -r '.items[].status.loadBalancer.ingress[].ip'):8080/ui"
```
Refresh multiple times and take note of the POD IP Addresses changing.

The AKS cluster was built with 3 nodes evenly spread across 3 AZs. Verify all `api` and `web` pods are running on the same node and take note of the node name.  
```
#kw1 is an alias for kubectl -n westus2-1
kw1 get pods -o wide
```
These pod IPs should be the same IPs you see in the `web` and `api` services in the browser.  

Verify the Availability Zone each AKS node is running in.  Find the node name that is running your services.  This node should be running in westus2-1.
```
kubectl get nodes -o custom-columns=NAME:'{.metadata.name}',REGION:'{.metadata.labels.topology\.kubernetes\.io/region}',ZONE:'{metadata.labels.topology\.kubernetes\.io/zone}'
```
If all services were deployed to the westus2-1 AKS node then there is no cross AZ traffic happening and everything was deployed according to the zone based nodeAffinity rules.

Next, deploy the api service into the kubernetes westus2-2 namespace.  With mirroring turned on that means they are also running in the Consul namespace westus2-2. All services in this namespace have been deployed with nodeAffinity rules to target the westus2-2 zone.

```
kubectl apply -f apps/fake-service/westus2/westus2-2/
```
Refresh the web service in your browser a few times to verify its only routing requests to the pods running in zone westus2-1 still.  

After the routing is verified kill all api services in westus2-1 and test that the web service will failover to services running in westus2-2.
```
kubectl delete -f apps/fake-service/westus2/westus2-1/api.yaml
```
Give the service a couple seconds to terminate.  Now refresh your browser again and look at the IP of the api service.  This POD IP should now be coming from from the services running in westus2-2. Use the same steps above to verify the services in the namespace westus2-2 are actually running on a node in zone westus2-2.

```
#kw2 is an alias for kubectl -n westus2-2
kw2 get pods -o wide

kubectl get nodes -o custom-columns=NAME:'{.metadata.name}',REGION:'{.metadata.labels.topology\.kubernetes\.io/region}',ZONE:'{metadata.labels.topology\.kubernetes\.io/zone}'
```

You should have successfully tested the failover for the api service across zone1 to zone2.  This was done using Consul namespaces.  The services were organized by kubernetes namespaces and deployed with nodeAffinity rules that targeted a specific zone.  consul created or organized its services based on the kubernetes namespaces for convenience.  With a service resolver you configured a failover rule using consul namespaces. This was part of the initial deployment `apps/fake-service/westus2/westus2-1/traffic-mgmt.yaml`
```
apiVersion: consul.hashicorp.com/v1alpha1
kind: ServiceResolver
metadata:
  name: api
  namespace: westus2-1
spec:
  connectTimeout: 0s
  failover:
    '*':
      service: api
      namespace: westus2-2
``` 