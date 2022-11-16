# Consul Enterprise on AKS
<!-- TOC -->

- [Consul Enterprise on AKS](#consul-enterprise-on-aks)
  - [How to Use This Repo](#how-to-use-this-repo)
  - [Quickstart](#quickstart)
    - [License](#license)
    - [Next Steps...](#next-steps)

<!-- /TOC -->
This includes Terraform modules for provisioning two
[peered](https://developer.hashicorp.com/consul/docs/connect/cluster-peering) Consul Enterprise clusters in different regions on [AKS](https://azure.microsoft.com/en-us/services/kubernetes-service/) using Consul.

## How to Use This Repo

- Ensure you have installed the [Azure
  CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) and are able to [authenticate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli) to your account.
- [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner) role or equivalent is required.
- Install [kubectl](https://kubernetes.io/docs/reference/kubectl/) (this will be used to verify Consul cluster federation status).
- Use the [quickstart-multiregion](https://github.com/ppresto/terraform-azure-consul-ent-aks/tree/main/quickstart-multiregion) terraform code to create the pre-reqs needed to install and federate or peer Consul clusters across Azure regions on AKS.  This will create the necessary RGs, VNETs, and AKS clusters across two regions.

## Quickstart
Review [quickstart_multiregion/README.md](./quickstart_multiregion/README.md)
Setup all Azure PreReqs using Terraform
```
cd terraform-azure-consul-ent-aks/quickstart_multiregion
```

### License
After completing the PreReqs, copy your Consul ENT License to `./files/consul.lic`

### Next Steps...
Once the Pre-Reqs are completed and all 4 AKS clusters across the two regions and their AZs are validated consul is ready to be installed.  This section will be updated with the next steps needed.

Coming soon..