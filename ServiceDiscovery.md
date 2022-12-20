# Service Discovery

<!-- TOC -->

- [Service Discovery](#service-discovery)
  - [Quickstart](#quickstart)
    - [License](#license)
    - [Consul Cluster Terraform](#consul-cluster-terraform)
  - [Deploy Primary Consul clusters using Helm](#deploy-primary-consul-clusters-using-helm)
    - [Kubectl - Validate Primary clusters via CLI](#kubectl---validate-primary-clusters-via-cli)
    - [Consul UI - Validate Primary Consul clusters with the UI](#consul-ui---validate-primary-consul-clusters-with-the-ui)
  - [Setup AKS DNS Forwarding to Consul](#setup-aks-dns-forwarding-to-consul)
    - [Informational - Step by Step](#informational---step-by-step)
  - [Deploy Services to test Service Discovery](#deploy-services-to-test-service-discovery)
  - [Setup Failover](#setup-failover)
    - [Validate Failover](#validate-failover)
  - [Troubleshooting](#troubleshooting)
    - [DNS AKS coredns](#dns-aks-coredns)
    - [DNS Consul](#dns-consul)

<!-- /TOC -->

## Quickstart
Review [quickstart_multiregion/README.md](./quickstart_multiregion/README.md)
Follow the README to setup all Azure PreReqs and run Terraform.  Use to the `example-tfvars/my.sd.auto.tfvars` to configure Consul helm values appropriately for service discovery in your environment.
```
cd terraform-azure-consul-ent-aks/quickstart_multiregion
cp example-tfvars/my.sd.auto.tfvars ./my.auto.tfvars
```

### License
After completing the PreReqs, copy your Consul ENT License to `./files/consul.lic`

### Consul Cluster Terraform
When using `quickstart_multiregion` this will automatically create the required tf files that will use the helm provider to deploy Consul next. 
- `./consul-primary/auto-main.tf`    # Creates 2 primary clusters for Peering
- `./consul-secondary/auto-main.tf`  # WAN Federation Only - Ignore when using Peering
- `./consul-dataplane/auto-main.tf`  # Bootstraps Agentless K8s clusters to consul mesh

## Deploy Primary Consul clusters using Helm
Run `terraform init` and `terraform apply` first in `./consul-primary` to set up your primary Consul cluster/s. Wait for the apply to complete before setting up any secondary or dataplane client clusters.  This will create the secrets required to bootstrap a secondary WAN federated cluster or dataplane client depending on your architecture.
```
cd .. # Go to the base of the repo
cd consul-primary
terraform init
terraform apply -auto-approve
```

### Kubectl - Validate Primary clusters via CLI
Connect to the AKS cluster and verify you can use kubectl.  If you missed this step in the `quickstart_multiregion` please source this script in your shell for AKS contexts and namespace aliases.
```
cd ../quickstart_multiregion
source kubectl_connect.sh
```
Refer to the quickstart-multiregion [README.md](https://github.com/hashicorp/terraform-azure-consul-ent-aks/blob/main/examples/quickstart-multiregion/README.md) for more information or review the script to learn more about kubectl commands and the aliases it creates in your shell.


List consul services
```shell
consul0  # switch context to the primary Consul cluster
kc get pods # kc alias = kubectl -n consul
kc exec -it consul-server-0 -- consul catalog services  # list services 
```
Consul resources are deployed into a `consul` k8s namespace.  use the `consul1` alias to switch to the primary cluster in the second region (westus2) and review pod READY status and the service catalog to verify the cluster is operational.

### Consul UI - Validate Primary Consul clusters with the UI
When installing Consul the helm values enabled the UI with an external LoadBalancer IP for easy access.  This is not recommended for production.  Use the following scripts to get the URL and login token for full access to each Consul cluster UI.
```
cd .. # Go to repo base
examples/ui/get_consul0_ui_url.sh
examples/ui/get_consul1_ui_url.sh
```
Both Consul clusters are setup the same. The upper left corner shows the consul datacenter name `consul0-eastus` or `consul1-westus2` that was configured in the helm values.  Go to the default Admin Partion, and Namespace to review the server.
- Services:     See the core Consul services (consul, mesh-gateway).
- Nodes:        The 3 nodes that make up the Consul cluster with leader identified
- Auth Methods: The K8s API used to authenticate consul cluster services
Check out the default policies, roles, and tokens that were created

## Setup AKS DNS Forwarding to Consul
CoreDNS running on AKS needs to be updated to forward .consul domain traffic to consul for lookups.  Use the following script to update DNS on both consul clusters (consul0, consul1).
```
cd examples/dns
./configure_dns_forwarding.sh
```

### Informational - Step by Step
If you ran the script you can skip this informational section.  This script above is doing the following To forward .consul requests to Consul for DNS resolution.

Get the Consul DNS clusterIP in the AKS cluster.
```
consul1  # example using consul1 cluster
dnsIP=$(kubectl -n consul get svc consul-dns --output jsonpath='{.spec.clusterIP}')
echo $dnsIP
```

Configure AKS coredns-custom config map with this ClusterIP.
```
cat examples/dns/coredns-custom.yaml | sed "s/IPADDRESS/${dnsIP}/g" | kubectl apply -f -
```

Restart AKS coredns
```
kubectl delete pod --namespace kube-system -l k8s-app=kube-dns
```

Validate Consul DNS resolution is working.
```
kubectl run busybox --restart=Never --image=busybox:1.28 -- sleep 3600
kubectl exec busybox -- nslookup consul.service.consul
```

You should see your 3 node consul cluster resolved.
```
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local

Name:      consul.service.consul
Address 1: 172.17.6.102 172-17-6-102.consul-ui.consul.svc.cluster.local
Address 2: 172.17.6.140 consul-server-2.consul-server.consul.svc.cluster.local
Address 3: 172.17.6.162 consul-server-1.consul-server.consul.svc.cluster.local
```

## Deploy Services to test Service Discovery
Services will be deployed on the Consul clusters for simplicity.  Service discovery does support running services on one to many remote AKS clusters.  The following script will deploy services (api, web) in both eastus and westus2 clusters and output the URL.  Wait and rerun the script if the URL is blank because sometimes the LB resource takes to long to get an IP.

```
cd ../examples/apps-nonmesh/fake-service
./deploy.sh
```
Review both eastus/westus2 consul clusters to see the new services deployed.  Consul catalog-sync service is registering all K8s services into consul automatically.  Services in the eastus should be working.  Services in westus2 are not working because they are setup for failover and we haven't set this up yet.

## Setup Failover
Peer eastus and westus2 Consul clusters together to test failover.  Once Peered each consul cluster can define what services it wants to export.  In this case eastus will export the `api` service to westus2.  
```
cd ../peering
./peer_consul0_to_consul1.sh
```
Now the clusters can discover and route to each others services, but there is one more step required to setup failover. Configure a Prepared Query in the westus2 consul cluster.  This will tell consul to use the local api serice, but if its not available failover to the `api` services being exported from eastus.  PQ use the following DNS format.  `<service_name>.query.consul`.  In this example we are appending a string `-ha` to the service_name.
```
api-ha.query.consul
```

Create the PQ using the following script.
```
cd ../fake-service
./create-pq.sh
```
This script will create a prepared query for you.  You can list this PQ and even delete it if you want to recreate.
```
./create-pq.sh list  # see PR and get UUID
./create-pq.sh delete <UUID>
```

Review the web service `../fake-service/westus2/web.yaml` to verify the name being used to access `api` matches  the example above.  Now check the URL for the westus2 services.  It should be working because the PQ has created an entry allowing `api-ha.query.consul` to be resolvable.

### Validate Failover
Look at the URL for the services in westus2.  The `api` service IP address is being served from westus2.  To test failover delete the api service in that datacenter.
```
consul1
kubectl delete -f westus2/api.yaml
```
Refresh the URL and you should see the `api` service is still available.  The IP addresses are coming form a new network that lives in eastus.

Once the PQ is created


## Troubleshooting
### DNS AKS coredns
Review defaul AKS coredns
```
kubectl get configmaps --namespace=kube-system coredns -o yaml 
```

If log.override is configured then query the dns logs.  The URL below explains this in more detail.
```
kubectl logs --namespace kube-system --selector k8s-app=kube-dns
```

### DNS Consul
Get DNS services (consul and coredns), start busybox, and use nslookup
```
consuldnsIP=$(kubectl -n consul get svc consul-dns -o json | jq -r '.spec.clusterIP')
corednsIP=$(kubectl -n kube-system get svc kube-dns -o json | jq -r '.spec.clusterIP')
kubectl run busybox --restart=Never --image=busybox:1.28 -- sleep 3600
kubectl exec busybox -- nslookup kubernetes $corednsIP
```
Additional examples:
```
kubectl exec busybox -- nslookup consul.service.consul
kubectl exec busybox -- nslookup api.service.az1.ns.default.ap.aks1-westus2.dc.consul
kubectl exec busybox -- nslookup api.virtual.az1.ns.default.ap.aks1-westus2.dc.consul
```

Ref: https://learn.microsoft.com/en-us/azure/aks/coredns-custom