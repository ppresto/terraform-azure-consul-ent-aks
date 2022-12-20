# Example Prerequisite Configuration for Consul on AKS Module

The quickstart directory provides example code that will create two resource groups each with their own VNET, and AKS cluster along with a native cloud Vault to share secure Consul data.  This will also generate the terraform needed to run the helm-install module to install Consul on AKS clusters.

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
- `resource_name_prefix` - Prefix for resource names VNet

The default Azure region is `East US`. If you wish to change this region,
you may select another region from the list provided and update the `./quickstart-multiregion/my.auto.tfvars`.
[here](https://azure.microsoft.com/en-us/global-infrastructure/geographies/#geographies).

### Sample [my.auto.tfvars](./quickstart_multiregion/my.auto.tfvars)
Do not use in production.  This example is using a path of a cloned consul-k8s repo for `consul_chart_name`  to build a configuration that will run the latest dev helm chart not yet released.  For stability replace this path with `consul` and then define a chart version with `consul_helm_chart_version`.  Additional example my.auto.tfvar files are in `./example-tfvars`.

```
regions              = ["eastus", "westus2"]
region_cidr_list     = ["172.16.0.0/16", "172.17.0.0/16"]
resource_name_prefix = "presto"
create_consul_tf     = true
consul_node_count    = 3
consul_version       = "1.14.0-ent"
consul_helm_chart_template = "values-peer-cluster-dev.yaml"  #clone consul-k8s main branch locally
consul_client_helm_chart_template = "values-client-aks-dev.yaml"
consul_chart_name         = "/Users/patrickpresto/Projects/consul/consul-k8s/charts/consul"
enable_cluster_peering    = true
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

## WAN Federation Only - Deploy Secondary Consul clusters using Helm
Skip this step if not setting up a WAN Federated architecture because you cant have secondary clusters.

Run `terraform init` and `terraform apply` in `./consul-secondary` to set up your secondary Consul cluster. Once this is complete, you should have two federated Consul clusters.
```
cd ../consul-secondary
rm -rf auto-consul1.tf  # Consul1 cluster not needed.
terraform init
terraform apply -auto-approve
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
Node                 Address            Status  Type    Build       Protocol  DC   Partition  Segment
consul-server-0.dc1  172.16.2.127:8302  alive   server  1.11.5+ent  2         dc1  default    <all>
consul-server-0.dc2  172.17.2.150:8302  alive   server  1.11.5+ent  2         dc2  default    <all>
consul-server-1.dc1  172.16.2.199:8302  alive   server  1.11.5+ent  2         dc1  default    <all>
consul-server-1.dc2  172.17.2.205:8302  alive   server  1.11.5+ent  2         dc2  default    <all>
consul-server-2.dc1  172.16.2.164:8302  alive   server  1.11.5+ent  2         dc1  default    <all>
consul-server-2.dc2  172.17.2.140:8302  alive   server  1.11.5+ent  2         dc2  default    <all>
```

## Complete
At this point your Azure Infrastructure should be built and you are ready to plan out your Consul installation.  Go back to the `../README.md` in the base of the repo for next steps...

# Note:
- If you have used the helm-install module to install the Consul helm chart on each consul cluster, please be sure to run `terraform destroy` from there to uninstall the helm chart BEFORE destroying these prerequisite resources. Failure to uninstall Consul from the main module will result in a failed `terraform destroy` and lingering resources in your VNET.
