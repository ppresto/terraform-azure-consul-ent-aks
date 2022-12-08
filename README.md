# Consul Enterprise on AKS
<!-- TOC -->

- [Consul Enterprise on AKS](#consul-enterprise-on-aks)
  - [How to Use This Repo](#how-to-use-this-repo)
  - [Quickstart](#quickstart)
    - [License](#license)
    - [Consul Cluster Terraform](#consul-cluster-terraform)
  - [Deploy Primary Consul clusters using Helm](#deploy-primary-consul-clusters-using-helm)
    - [Kubectl - Validate Primary clusters via CLI](#kubectl---validate-primary-clusters-via-cli)
    - [Consul UI - Validate Primary Consul clusters with the UI](#consul-ui---validate-primary-consul-clusters-with-the-ui)
  - [Deploy Agentless Dataplane to AKS clusters using Helm](#deploy-agentless-dataplane-to-aks-clusters-using-helm)
  - [WAN Federation Only - Deploy Secondary Consul clusters using Helm](#wan-federation-only---deploy-secondary-consul-clusters-using-helm)
    - [Verify WAN Federated Datacenters see each other](#verify-wan-federated-datacenters-see-each-other)
  - [Examples](#examples)
  - [AKS DNS Forwarding to Consul (Optional)](#aks-dns-forwarding-to-consul-optional)
  - [Troubleshooting](#troubleshooting)
    - [DNS AKS coredns](#dns-aks-coredns)
    - [DNS Consul](#dns-consul)
    - [Helm](#helm)
      - [Primary Consul Cluster using main branch (latest development)](#primary-consul-cluster-using-main-branch-latest-development)
      - [Client Dataplane - AKS Cluster using beta version](#client-dataplane---aks-cluster-using-beta-version)
    - [CA Cert](#ca-cert)
    - [Connect - Peer Failover Targets](#connect---peer-failover-targets)
  - [References](#references)
  - [Next Steps](#next-steps)
    - [Deploying Example Applications](#deploying-example-applications)
  - [License](#license-1)

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

### Consul Cluster Terraform
When using `quickstart_multiregion` setting variable `create_consul_tf = true` will automatically create the required tf files that will use the helm provider to deploy Consul. 
- `./consul-primary/auto-main.tf`    # Cluster Peering creates 1+ primaries
- `./consul-secondary/auto-main.tf`  # Created with WAN Federation Only
- `./consul-clients/auto-main.tf`    # Created for Agentless K8s clusters only

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

## Deploy Agentless Dataplane to AKS clusters using Helm
If setting up a dataplane/agentless AKS cluster architecture run this section and skip the following section.

Identify the two consul cluster external service IP addresses first.
```
#consul0
kc get svc consul-expose-servers -o json --context consul0 | jq -r '.status.loadBalancer.ingress[].ip'
#consul1
kc get svc consul-expose-servers -o json --context consul1 | jq -r '.status.loadBalancer.ingress[].ip'
```

Update the auto generated client files with their correct consul_external_servers IP Address.
- `consul-clients/auto-aks0.tf` -> consul0
- `consul-clients/auto-aks0.tf` -> consul1
```
# example
consul_external_servers    = "172.16.2.11"
```
Once the tf files are updated with the proper IP, run `terraform init` and `terraform apply` in `./consul-clients` to bootstrap the AKS cluster to Consul. 
```
cd ../consul-clients
terraform init
terraform apply -auto-approve
```
Once this is complete, you should have an agentless AKS cluster connected to Consul.  Verify the dataplane is connected to the consul cluster and healthy.  Use the `aks0` alias to switch to the first regions agentless AKS cluster.  Then use the `kc` alias to see resources in the consul namespace.  The connect-injector pod's log should show a successful connection to consul0.
```
aks0
kc get pods
kc logs <aks0-connect-injector-...> | grep -i consul-server-connection-manager
```

Log output should look like this.
```
[INFO]  consul-server-connection-manager: trying to connect to a Consul server
[INFO]  consul-server-connection-manager: discovered Consul servers: addresses=[172.16.2.11:8502]
[INFO]  consul-server-connection-manager: current prioritized list of known Consul servers: addresses=[172.16.2.11:8502]
[INFO]  consul-server-connection-manager: ACL auth method login succeeded
[INFO]  consul-server-connection-manager: connected to Consul server: address=172.16.2.11:8502
```

The helm values used to deploy the Consul dataplane created a new partition and boostrapped the AKS cluster to it.  In the UI go to the Admin Partition drop down menu and select `shared`.  You should see 2 healthy services.
- `ingress-gateway` is used to allow requests into the service mesh
- `mesh-gateway` is used to extend the service mesh by connecting to remote partitions

At this point, the Namespace drop down menu will only have the default.  This is because we haven't started any services in the AKS cluster within its own K8s namespace.  Once we start services in their own k8s namespace Consul will automatically create a 1/1 Consul namespace for the service providing it with extra adminstrative and service mesh capabilities.

Consul servers and remote dataplanes (AKS east/west clusters) are setup and ready to register services.  [Deploy example services](./examples/README.md) to test out Consul service mesh.

```
cd ../examples/apps/fake-service
./deploy.sh
```

Peer east/west regions to test failover
```
cd ../../peering
./peer_aks0_to_aks1.sh
```
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
## Examples
Review [Examples](./examples/README.md) for scripts that show how to setup the UI, CLI, deploy sample apps, and other consul configurations.

## AKS DNS Forwarding to Consul (Optional)
DNS forwarding is only needed for Service discovery.  This is not required if using service mesh.  To setup DNS forwarding configure the AKS cluster to forward .consul requests to Consul DNS resolution.  This will allow you to leverage Consul DNS for failover and other L7 traffic mgmt features.

Get the Consul DNS clusterIP in the AKS cluster you want to setup.
```
aks1  # example using AKS1 cluster
dnsIP=$(kubectl -n consul get svc consul-dns --output jsonpath='{.spec.clusterIP}')
```

Configure AKS coredns-custom config map with this ClusterIP.
```
cat examples/dns/coredns-custom.yaml | sed "s/IPADDRESS/${dnsIP}/g" | kubectl apply -f -
```

Restart AKS coredns
```
kubectl delete pod --namespace kube-system -l k8s-app=kube-dns
```

Validate Consul DNS resolution
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

### Helm
When troubleshooting or trying out new helm chart values you may want to manually use helm to install, upgrade, or delete Consul.  After running terraform to manage the helm install auto-* files will be created with the helm values used by terraform.  You can use these files to see exactly what values were used and to manually uninstall and upgrade Consul config as needed.
```
./consul-primary/yaml/
./consul-secondary/yaml/
./consul-clients/yaml/
```
You can also review `./consul-secondary/yaml/manual_install.sh` for tips to setup helm repo, copy k8s secrets from one cluster to another and install consul.

#### Primary Consul Cluster using main branch (latest development)
clone the hashicorp/consul-k8s repo locally to run the latest helm chart.  This is required to test the newest features not yet released or available in beta.

consul0
```
cd consul-primary
terraform init
terraform apply -auto-approve
```

If TF release times out use helm kubectl to troubleshoot.
```
helm -n consul list  # get release name
helm -n consul history <release-name>
kubectl -n consul get pods
kubectl -n consul get svc
kubectl -n consul describe pod <name>
kubectl -n consul logs <pod>
```

Uninstall the helm chart and verify the environment is clean before reinstalling
```
# use consul-k8s CLI for clean uninstall and PVC deletion.
consul-k8s uninstall -auto-approve -wipe-data

# If using helm instead, ensure crd, pv, pvc resources are removed
helm -n consul uninstall consul0-eastus
kubectl get all
kubectl get crd
```

Edit `yaml/auto-consul0-eastus-values.yaml` with changes and test install.
```
helm install consul0-eastus -n consul -f yaml/auto-consul0-eastus-values.yaml /Users/patrickpresto/Projects/consul/consul-k8s/charts/consul
```

#### Client Dataplane - AKS Cluster using beta version
This repo will create 1 client cluster per region by default.  Connect to your client cluster with kubectl.  The default contexts are `aks0, aks1`, 1 for each region.  These client clusters require a boostrap token and CA cert from the primary Consul cluster so copy those over to the dataplane before installation.

```
aks0
kubectl create ns consul

kubectl -n consul get secret consul-bootstrap-acl-token --context consul0 -o yaml \
| kubectl apply --context aks0 -f -

kubectl -n consul get secret consul-ca-cert --context consul0 -o yaml \
| kubectl apply --context aks0 -f -

helm -n consul install aks0-eastus hashicorp/consul --version 1.0.1 -f yaml/auto-aks0-eastus-values.yaml

# helm -n consul uninstall aks0-eastus
# consul-k8s uninstall -auto-approve -wipe-data

```

### CA Cert

Use openssl to view a cert in k8s secrets.
```
kubectl get secret -n consul consul-ca-cert -o jsonpath="{.data['tls\.crt']}" | base64 --decode | openssl x509 -text -noout
```

### Connect - Peer Failover Targets

Discovery Chain - verify protocols are all http
```
# use-context for westus2 consul cluster
consul1

export CONSUL_HTTP_TOKEN=$(kubectl get --namespace consul secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)

kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/discovery-chain/api | jq -r
```
Endpoint should point to the MG on the other side
```
kubectl -n consul exec -it consul-server-0 -- curl -k --header "X-Consul-Token: ${CONSUL_HTTP_TOKEN}" --request GET https://localhost:8501/v1/health/connect/api?peer=consul0-eastus | jq -r

#curl -sL "localhost:8500/v1/health/connect/unicorn-backend?ns=default&partition=unicorn&peer=dc2-unicorn"
```

Debug logging
```
curl -XPOST localhost:19000/logging?level=debug
```


## References
https://developer.hashicorp.com/consul/tutorials/kubernetes/kubernetes-secure-agents


**NOTE**: when running `terraform destroy` on this module to uninstall Consul, please run `terraform destroy` on any client or secondary Consul clusters first and wait for it to complete before destroying primary consul clusters.

## Next Steps

### Deploying Example Applications
To deploy and configure some example applications, please see the
[apps](https://github.com/ppresto/terraform-azure-consul-ent-aks/tree/main/examples/apps/fake-services) directory.


## License
This code is released under the Mozilla Public License 2.0. Please see
[LICENSE](https://github.com/hashicorp/terraform-azure-consul-ent-aks/blob/main/LICENSE)
for more details.
