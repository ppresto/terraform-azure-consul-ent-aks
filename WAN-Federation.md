# Example Prerequisite Configuration for Consul on AKS Module

The quickstart directory provides example code that will create two resource groups each with their own VNET, and AKS cluster along with a native cloud Vault to share secure Consul data.  This will also generate the terraform needed to run the helm-install module to install Consul in a WAN Federated model on AKS clusters.

## How to Use This Repo

- Ensure you have installed the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) and are able to [authenticate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli) to your account.
  - [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner) role or equivalent is required.
- Install [Terraform 1.2+](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) to provision Azure infrastructure
- Install [kubectl](https://kubernetes.io/docs/reference/kubectl/)

### License
After completing the PreReqs, copy your Consul ENT License to `./files/consul.lic`


## PreReqs

### Required Variables

- `regions`              = List of regions with primary being first
- `region_cidr_list`     = List with a CIDR block for each region
- `resource_name_prefix` = Prefix for resource names
- `consul_version`       = "1.14.3-ent"
- `enable_cluster_peering` = false
- `consul_helm_chart_version`  = "1.0.2"

The default Azure region is `East US`. If you wish to change this region,
you may select another region from the list provided and update the `./quickstart-multiregion/my.auto.tfvars`.
[here](https://azure.microsoft.com/en-us/global-infrastructure/geographies/#geographies).

### Sample [my.auto.tfvars](./quickstart_multiregion/my.auto.tfvars)
Additional Peering, and ServiceDiscovery example files are in `./example-tfvars`.

```
regions              = ["eastus", "westus2"]
region_cidr_list     = ["172.16.0.0/16", "172.17.0.0/16"]
resource_name_prefix = "presto"
create_consul_tf     = true
consul_node_count    = 3
consul_version       = "1.14.3-ent"
enable_cluster_peering = false
consul_helm_chart_version  = "1.0.2"
```
### AKS Cluster Networking

The AKS clusters can be built with Azure-CNI networking which means every node and pod has a routable IP.  To enabkle this update the `main.tf` and `aks_apps.tf` files to use the aks-cni module.
```
# aks module used in main.tf and aks_apps.tf
source         = "../modules/aks-cni/"
```

The AKS clusters will be built with kubenet networking which is the Azure default. If you dont want to manage IP ranges, are worried about running out of IPs, or dont want every pod routable then Azure kubenet networking is what you want.  All pods run behind a NAT with non routable IP's.  Nodes do have routable IPs.  You can see this module in `main.tf` and `aks_apps.tf`.
```
source         = "../modules/aks-kubenet/"
```

### Consul Cluster Terraform
FYI: The required tf files that will use the helm provider to deploy Consul are auto generated.
- `./consul-primary/auto-main.tf`    # Cluster Peering creates 1+ primaries
- `./consul-secondary/auto-main.tf`  # Created with WAN Federation Only

## Getting Started

### Setup Environment
Export the requird ARM environment variables with your subscription id information.  Terraform will use these variables in your current working environment for authN/authZ.
```
export ARM_SUBSCRIPTION_ID=<input>
export ARM_CLIENT_SECRET=<input>
export ARM_TENANT_ID=<input>
export ARM_CLIENT_ID=<input>
```

### Build the AKS clusters with Terraform
```
cd ./quickstart_multiregion
terraform init
terraform apply -auto-approve
```

## Connect to AKS clusters to run kubectl

If you want to run `kubectl` commands against your cluster, be sure to update your kubeconfig with the Azure CLI. Source the `./kubectl_connect.sh` script to update kubeconfig and also apply aliases to your working environment.  These aliases help switching AKS context's quickly and accessing the different k8s namespaces that are being created by region+az.

```shell
source ./kubectl_connect.sh
```
output
```
### Region: eastus
	AKS Context Aliases
		consul0	- kubectl config use-context consul0
		aks0	- kubectl config use-context aks0
	Namespace Alias
		ke1 - kubectl -n eastus-1
		ke2 - kubectl -n eastus-2
		ke3 - kubectl -n eastus-3
		kc - kubectl -n consul

### Region: westus2
	AKS Context Aliases
		consul1	- kubectl config use-context consul1
		aks1	- kubectl config use-context aks1
	Namespace Alias
		kw1 - kubectl -n westus2-1
		kw2 - kubectl -n westus2-2
		kw3 - kubectl -n westus2-3
		kc - kubectl -n consul
```

This script uses your local ARM credentials to loop through the resource groups and AKS clusters.  Using the Azure CLI it updates kubeconfig with the needed AKS creds with a command like below.
```shell
$ az aks get-credentials --resource-group "<resource group name>" --name "<name of cluster>"
```

Test using the aliases to quickly switch contexts between AKS clusters in the primary region.
```
aks0
consul0
```
These aliases use kubectl to switch [context](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#context).

```shell
$ kubectl config use-context "<your cluster name>"
```

## Verify AZ
If you tested the aliases above then your current context should be consul0 which will be the AKS cluster hosting Consul servers in region eastus.  Now that you are connected, verify the nodes are evenly spread across AZs.  The default node count for the consul cluster is set to 3 and the target regions have 3 zones so they should be evenly spread across the zones.

- `aks-consulpool` : consul servers will use this 3 node pool.
- `aks-default`    : AKS services will use this 3 node pool.

```shell
kubectl get nodes -o custom-columns=NAME:'{.metadata.name}',REGION:'{.metadata.labels.topology\.kubernetes\.io/region}',ZONE:'{metadata.labels.topology\.kubernetes\.io/zone}'

NAME                                 REGION   ZONE
aks-consulpool-12127614-vmss000000   eastus   eastus-2
aks-consulpool-12127614-vmss000001   eastus   eastus-3
aks-consulpool-12127614-vmss000002   eastus   eastus-1
aks-default-32425529-vmss000000      eastus   eastus-2
aks-default-32425529-vmss000001      eastus   eastus-3
aks-default-32425529-vmss000002      eastus   eastus-1
```
Read more on AZ [here](https://learn.microsoft.com/en-us/azure/aks/availability-zones).

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

```shell
consul0  # switch context to the primary Consul cluster
kc get pods # kc alias = kubectl -n consul
kc exec -it consul-server-0 -- consul catalog services  # list services 
```
Consul resources are deployed into a `consul` k8s namespace.  use the `consul1` alias to switch to the cluster in the second region (westus2) and review pod READY status and the service catalog to verify the cluster is operational.

### Consul UI - Validate Consul clusters with the UI
When installing Consul the helm values enabled the UI with an external LoadBalancer IP for easy access.  This is not recommended for production.  Use the following scripts to get the URL and login token for full access to each Consul cluster UI. 

```
cd .. # Go to repo base
examples/ui/get_consul0_ui_url.sh
```
In the UI the upper left corner shows the consul datacenter name `consul0-eastus` or `consul1-westus2` that was configured in the helm values.  Go to the default Admin Partion, and Namespace to review the server.
- Services:     See the core Consul services (consul, mesh-gateway).
- Nodes:        The 3 nodes that make up the Consul cluster with leader identified
- Auth Methods: The K8s API used to authenticate consul cluster services
Check out the default policies, roles, and tokens that were created.

## Deploy and federate the secondary Consul cluster using Helm

Run `terraform init` and `terraform apply` in `./consul-secondary` to set up secondary Consul clusters. Once this is complete, you should have two federated Consul clusters.
```
cd ../consul-secondary
# rm -rf auto-consul1.tf  # Remove 1+ auto-*.tf files to reduce secondary clusters.
terraform init
terraform apply -auto-approve
```

FYI: With WAN Federated clusters the secondary cluster will not have a login token.  Use the primary cluster's token to login from the example above.  The script below will give the URL in this case, but no token.
```
cd .. # Go to repo base
examples/ui/get_consul1_ui_url.sh
```

### Verify WAN Federated Datacenters see each other
To verify a WAN Federated primary and all secondary Consul datacenters are federated, run the consul members -wan
command on one of the Consul server pods.

```shell
consul0  # Alias to switch to primary consul AKS cluster
kubectl exec statefulset/consul-server --namespace=consul -- consul members -wan
```

Your output should show servers from both `dc1` and `dc2` similar to what is
show below:

```shell
Node                             Address           Status  Type    Build       Protocol  DC               Partition  Segment
consul-server-0.consul0-eastus   10.244.3.43:8302  alive   server  1.14.3+ent  2         consul0-eastus   default    <all>
consul-server-0.consul1-westus2  10.244.5.13:8302  alive   server  1.14.3+ent  2         consul1-westus2  default    <all>
consul-server-1.consul0-eastus   10.244.5.29:8302  alive   server  1.14.3+ent  2         consul0-eastus   default    <all>
consul-server-1.consul1-westus2  10.244.4.16:8302  alive   server  1.14.3+ent  2         consul1-westus2  default    <all>
consul-server-2.consul0-eastus   10.244.4.49:8302  alive   server  1.14.3+ent  2         consul0-eastus   default    <all>
consul-server-2.consul1-westus2  10.244.3.11:8302  alive   server  1.14.3+ent  2         consul1-westus2  default    <all>
```

Verify remote services across each datacenter
```
# From the East look at the service catalog in the West
consul0
kubectl exec statefulset/consul-server --namespace consul -- consul catalog services -datacenter consul1-westus2

# West to East
consul1
kubectl exec statefulset/consul-server --namespace consul -- consul catalog services -datacenter consul0-eastus
```
## Deploy Services
Deploy services to the default Partition, and default Namespace of the K8s cluster that is hosting Consul.  The output of the script will give the Fake Service URL.
```
./examples/apps-wanf-to-peer-migration/deploy-consul0_consul1.sh
```
The westus2/web.yaml is defined with a static upstream pointing to eastus/api.yaml using WAN Federation.

## Verify ACL replication and create policies and tokens
If clients are enabled in the helm values then replication should be enabled and running on the secondary.  Run the following script to create policies and tokens on the primary to validate on the secondary after migration.  Use the API to verify secondary replication health.  Run the following script to do this.
```
examples/apps-wanf-to-peer-migration/migration/create_policies.sh
```

## Upgrade Consul Servers to support Peering
Review the upgrade docs at https://developer.hashicorp.com/consul/docs/k8s/upgrade

Upgrade the Secondary clusters first (ex: consul1)
```
cd consul-secondary
kubectl config use-context consul1
helm list --filter consul --namespace consul  # get current versions to update commands as needed.
```

Update the helm values to support Peering and additional features as needed.
`yaml/auto-consul1-westus2-values.yaml`
```
global:
	peering:
		enabled: true

connectInject:
  enabled: true
  transparentProxy:
    defaultEnabled: false

server:
  extraConfig: |
   {
     "log_level": "TRACE"
   }
```

Verify Changes
```
helm plugin install https://github.com/databus23/helm-diff
helm diff upgrade consul1-westus2 hashicorp/consul -n consul -f yaml/auto-consul1-westus2-values.yaml --version 1.0.2 | grep "has changed"
```

Run helm upgrade to configure new values.
```
helm upgrade consul1-westus2 hashicorp/consul -n consul -f yaml/auto-consul1-westus2-values.yaml --version 1.0.2
```
Refresh UI and check server/connector logs for errors.  May need to reapply service defaults.

Run the same steps on the remaining secondary clusters and do primary last.
```
cd ../consul-primary
kubectl config use-context consul0
helm upgrade consul0-eastus hashicorp/consul -n consul -f yaml/auto-consul0-eastus-values.yaml --version 1.0.2
```
Verify logs are clean.

## Configure Peering from consul0-eastus to consul1-westus2

Configure Peering to use MGW
```
consul0
examples/apps-wanf-to-peer-migration/fake-service/eastus/init-consul-config/mesh.yaml.dis

consul1
examples/apps-wanf-to-peer-migration/fake-service/westus2/init-consul-config/mesh.yaml.dis
```

Setup Acceptor, Dialer, and Exported Services
```
cd ..
examples/apps-wanf-to-peer-migration/peering/peer_consul0_to_consul1.sh
```

If `State = Pending` try editing the mesh-gateway deployment to have replicas: 1. 
```
kc edit deploy/consul-mesh-gateway
```

## Apply WAN/Peering Failover
Apply the Failover target rules, and then delete the local api service to verify failover works.  Comment out the peer or datacenter target to verify the other target is failover properly.
```
kubectl apply -f examples/apps-wanf-to-peer-migration/fake-service/westus2/traffic-mgmt.yaml.dis
kubectl delete -f examples/apps-wanf-to-peer-migration/fake-service/westus2/api.yaml
```

## Disable WAN Federation -  TBD
To remove WAN Federated nodes the clients must first be disabled.  Update the helm values of the secondary cluster (1.14.x) to disable clients.
```
cd consul-secondary
```

Update `yaml/auto-consul1-westus2-values.yaml`:
```
client:
  enabled: false
```

Remove clients using helm upgrade
```
helm upgrade consul1-westus2 hashicorp/consul -n consul -f yaml/auto-consul1-westus2-values.yaml --version 1.0.2
```

Remove WAN Serf listening port 8302 TCP/UDP from server-statefulset pods to break WAN Federation
```
kubectl -n consul edit statefulset consul-server
```
Not sure if port needs to be removed from consul-server service too??

Disable WAN Federation on secondary cluster
```
./examples/apps-wanf-to-peer-migration/migration/disable_wanfed.sh
```

Verify WAN Connection from primary and secondary
```
kubectl config use-context consul0
kubectl exec statefulset/consul-server --namespace consul -- consul members -wan
kubectl config use-context consul1
kubectl exec statefulset/consul-server --namespace consul -- consul members -wan
```

Update Helm values to remove all Federation configurations and upgrade cluster.
```
consul1
helm upgrade consul1-westus2 hashicorp/consul -n consul -f yaml/auto-consul1-westus2-values.yaml --version 1.0.2
```

## Complete
At this point your Azure Infrastructure should be built and you are ready to plan out your Consul installation.  Go back to the `../README.md` in the base of the repo for next steps...

# Note:
- If you have used the helm-install module to install the Consul helm chart on each consul cluster, please be sure to run `terraform destroy` from there to uninstall the helm chart BEFORE destroying these prerequisite resources. Failure to uninstall Consul from the main module will result in a failed `terraform destroy` and lingering resources in your VNET.
