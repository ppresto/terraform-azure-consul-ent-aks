# Consul Enterprise on AKS - Quickstart

The quickstart directory provides example code that will create two resource groups each with their own VNET, and AKS cluster along with a native cloud Vault to share secure service mesh data like certificates, tokens, and licensing.  This will also generate the terraform needed to install Consul on AKS clusters using the helm provider.

## PreReqs
- Azure subscription
- Ensure you have installed the [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) and are able to [authenticate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli) to your account.
  - [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner) role or equivalent is required.
- Install [Terraform 1.2+](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) to provision Azure infrastructure
- Install [kubectl](https://kubernetes.io/docs/reference/kubectl/)

## Getting Started
## Azure AKS Networking Configuration
Review AKS Networking.  AKS clusters are built with a default pool for kube-system, and a custom 3 node pool to run services.  The AKS clusters can be built with Azure-CNI networking which means every node and pod has a routable IP.  To enabkle this update the `main.tf` and `aks_apps.tf` files to use the aks-cni module.
```
# aks module used in main.tf and aks_apps.tf
source         = "../modules/aks-cni/"
```

The AKS clusters will be built with kubenet networking which is the Azure default. If you dont want to manage IP ranges, are worried about running out of IPs, or dont want every pod routable then Azure kubenet networking is what you want.  All pods run behind a NAT with non routable IP's.  Nodes do have routable IPs.  You can see this module in `main.tf` and `aks_apps.tf`.
```
source         = "../modules/aks-kubenet/"
```

### Setup Env
Export the requird ARM environment variables with your subscription id information.  Terraform will use these variables in your current working environment for authN/authZ.
```
export ARM_SUBSCRIPTION_ID=<input>
export ARM_CLIENT_SECRET=<input>
export ARM_TENANT_ID=<input>
export ARM_CLIENT_ID=<input>
```

### Required Variables

- `regions`              = List of regions with primary being first
- `region_cidr_list`     = List with a CIDR block for each region
- `resource_name_prefix` - Prefix for resource names VNet

The default Azure region is `East US`. If you wish to change this region,
you may select another region from [here](https://azure.microsoft.com/en-us/global-infrastructure/geographies/#geographies) and update the `./quickstart-multiregion/my.auto.tfvars`.

### Update [my.auto.tfvars](./my.auto.tfvars)
Setup your Azure Environment and Consul variables before running Terraform. This example config sets up 2 Azure regions and 2 networks.  Terraform will provisions 2 AKS clusters (one per region) that will deploy Consul 1.14.2-ent using version 1.0.2 of the consul helm chart.  

```
regions              = ["eastus", "westus2"]
region_cidr_list     = ["172.16.0.0/16", "172.17.0.0/16"]
resource_name_prefix = "rg-presto"
create_consul_tf     = true
consul_node_count    = 3
consul_version       = "1.14.2-ent"
consul_helm_chart_template = "values-peer-mesh.yaml"
consul_client_helm_chart_template = "values-client-aks.yaml"
consul_chart_name         = "1.0.2"
enable_cluster_peering    = true
```
Additional examples supporting different versions and use cases are in `./example-tfvars`.  In the default example above, the helm values will enable the following consul features.
* Service Mesh
* Mesh Gateway
* Peering
* Admin Partitions and Namespaces

`consul_helm_chart_template` points to the helm values template Terraform will use to configure Consul.  These templates are located in the [helm_install module](../modules/helm_install/tempmlates).  Review these to see how different use cases and features are being enabled.
### Build Azure Resources (RGs, VNETs, AKSs) with Terraform
```
cd ./quickstart_multiregion
terraform init
terraform apply -auto-approve
```

## Connect to AKS clusters to run kubectl

If you want to run `kubectl` commands against your cluster, be sure to update your kubeconfig with the Azure CLI. Source the `./kubectl_connect.sh` script to update kubeconfig and also apply aliases to your working environment.  These aliases help switching AKS context's quickly and accessing the different k8s namespaces that are being created for each region and availability zone.
- AKS Contexts
  - consul0, consul1 : AKS clusters hosting Consul in each region
  - aks0, aks1: AKS clusters hosting applications in each region

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

## Verify AZ
If you tested the aliases above then your current context should be consul0 which by default will be the AKS cluster hosting Consul servers in region eastus.  Now that you are connected, verify the nodes are evenly spread across AZs.  The default node count for the consul cluster is set to 3 and the target regions have 3 zones so they should be evenly spread across the zones.

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

## Complete
At this point your Azure Infrastructure should be built and you are ready to plan out your Consul installation.  Go back to the `../README.md` in the base of the repo for next steps...

# Note:
- If you have used the helm-install module to install the Consul helm chart on each consul cluster, please be sure to run `terraform destroy` from there to uninstall the helm chart BEFORE destroying these prerequisite resources. Failure to uninstall Consul from the main module will result in a failed `terraform destroy` and lingering resources in your VNET.
