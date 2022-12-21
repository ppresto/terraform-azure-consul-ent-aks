# Consul Enterprise on AKS
<!-- TOC -->

- [Consul Enterprise on AKS](#consul-enterprise-on-aks)
  - [How to Use This Repo](#how-to-use-this-repo)
  - [Quickstart](#quickstart)
    - [License](#license)
  - [Deploy Primary Consul clusters using Helm](#deploy-primary-consul-clusters-using-helm)
    - [Kubectl - Validate Primary clusters via CLI](#kubectl---validate-primary-clusters-via-cli)
    - [Consul UI - Validate Primary Consul clusters with the UI](#consul-ui---validate-primary-consul-clusters-with-the-ui)
    - [Deploy Services to Consul's default partition and namespace](#deploy-services-to-consuls-default-partition-and-namespace)
  - [Deploy Consul to Agentless AKS clusters using Helm](#deploy-consul-to-agentless-aks-clusters-using-helm)
  - [Deploy Services to remote AKS clusters](#deploy-services-to-remote-aks-clusters)
  - [Setup Peering (eastus/westus2)](#setup-peering-eastuswestus2)
  - [Test Failover](#test-failover)
  - [Examples](#examples)
  - [Troubleshooting](#troubleshooting)
    - [DNS Consul](#dns-consul)
    - [Helm](#helm)
      - [Timeout - Terraform Helm deployment](#timeout---terraform-helm-deployment)
      - [Use latest helm chart in development](#use-latest-helm-chart-in-development)
      - [Client Dataplane - AKS Cluster using beta version](#client-dataplane---aks-cluster-using-beta-version)
    - [CA Cert](#ca-cert)
    - [Connect - Review Peer Failover Targets](#connect---review-peer-failover-targets)
    - [Get Fake Service Pod IP's](#get-fake-service-pod-ips)
    - [Connect - Review Envoy Proxy configuration](#connect---review-envoy-proxy-configuration)
    - [Connect - Review Service Mesh defaults](#connect---review-service-mesh-defaults)
  - [References](#references)
  - [Next Steps](#next-steps)
    - [Deploying Example Applications](#deploying-example-applications)
  - [License](#license-1)

<!-- /TOC -->
This repo includes Terraform modules for provisioning two
[peered](https://developer.hashicorp.com/consul/docs/connect/cluster-peering) Consul Enterprise clusters in different regions on [AKS](https://azure.microsoft.com/en-us/services/kubernetes-service/).  This README focuses on service mesh, but this repo has other README's to cover Service Discovery and WAN Federation use cases.

## How to Use This Repo

- Ensure you have installed the [Azure
  CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) and are able to [authenticate](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli) to your account.
- [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner) role or equivalent is required.
- Install [kubectl](https://kubernetes.io/docs/reference/kubectl/) (this will be used to verify Consul cluster federation status).
- Use the [quickstart-multiregion](https://github.com/ppresto/terraform-azure-consul-ent-aks/tree/main/quickstart-multiregion) terraform code to create the pre-reqs needed to run the newer `Peered` Consul cluster Architecture spanning across Azure regions on AKS.  This will create the necessary RGs, VNETs, and AKS clusters across two regions. This README
- Use the [quickstart_multiregion_wanfed](https://github.com/ppresto/terraform-azure-consul-ent-aks/tree/main/quickstart_multiregion_wanfed) terraform code to create the pre-reqs needed to run a `WAN Federated` Consul cluster architecture that spans across Azure regions on AKS.  This will create the necessary RGs, VNETs, and AKS clusters across two regions.  Refer to the [quickstart_multiregion_wanfed/README.md](./quickstart_multiregion_wanfed/README.md) to setup a WAN Federated Architecture.

## Quickstart
Review [quickstart_multiregion/README.md](./quickstart_multiregion/README.md).  This guide will setup all Azure PreReqs and configure Consul helm values to enable service mesh, and Peering remote clusters across regions (eastus, westus2) for failover.  To learn about non service mesh use cases like service discovery with Peering refer to [ServiceDiscovery.md](./ServiceDiscovery.md).  The rest of this README will focus on Peering Consul clusters together to support service mesh across regions.

```
cd terraform-azure-consul-ent-aks/quickstart_multiregion
```

### License
After completing the PreReqs, copy your Consul ENT License to `./files/consul.lic`

## Deploy Primary Consul clusters using Helm
When using `quickstart_multiregion` this will automatically create the required tf files that will use the helm provider to deploy Consul. 
- `./consul-primary/auto-main.tf`    # Creates 2 primary clusters for Peering
- `./consul-secondary/auto-main.tf`  # WAN Federation Only - Ignore when using Peering
- `./consul-dataplane/auto-main.tf`    # Bootstraps Agentless K8s clusters to consul mesh
  
```
cd .. # Go to the base of the repo
cd consul-primary
terraform init
terraform apply -auto-approve
```
This will set up your primary Consul cluster/s. Wait for the apply to complete before setting up any dataplanes  (aka: agentless AKS clients).  This IaC will create the secrets required to bootstrap a secondary WAN federated cluster or dataplane client depending on your architecture.

### Kubectl - Validate Primary clusters via CLI
Connect to the AKS cluster and verify you can use kubectl.  If you missed this step in the `quickstart_multiregion` then source this script in your shell for AKS contexts and namespace aliases.
```
cd ../quickstart_multiregion
source kubectl_connect.sh
```
Refer to the quickstart-multiregion [README.md](https://github.com/hashicorp/terraform-azure-consul-ent-aks/blob/main/examples/quickstart-multiregion/README.md) for more information or review the script to learn more about kubectl commands and the aliases it creates in your shell.


List consul pods
```shell
consul0  # switch context to the primary Consul cluster in eastus region
kc get pods # kc alias = kubectl -n consul
```
Consul resources are deployed into a `consul` k8s namespace.  The `consul0` alias switches to the primary cluster in the primary region (eastus).  Listing pods should show a READY status

List consul catalog services using an ACL token.
```
consul0
export CONSUL_HTTP_TOKEN=$(kubectl -n consul get secrets consul-bootstrap-acl-token -o go-template --template="{{.data.token|base64decode}}")
kc exec -it consul-server-0 -- consul catalog services -token ${CONSUL_HTTP_TOKEN}

# Output
consul
ingress-gateway
mesh-gateway
```


### Consul UI - Validate Primary Consul clusters with the UI
When installing Consul the helm values enabled the UI with an external LoadBalancer IP for easy access.  This is not recommended for production.  Use the following scripts to get the URL and login token for full access to each Consul cluster UI.
```
cd .. # Go to repo base
examples/ui/get_consul0_ui_url.sh  # Datacenter consul0-eastus
examples/ui/get_consul1_ui_url.sh  # Datacenter consul1-westus2
```
Both Consul clusters are setup the same. The upper left corner shows the consul datacenter name `consul0-eastus` or `consul1-westus2` that was configured in the helm values.  Go to the default Admin Partion, and Namespace to review the server.
- Services:     See the core Consul services (consul, mesh-gateway).
- Nodes:        The 3 nodes that make up the Consul cluster with leader identified
- Auth Methods: The K8s API used to authenticate consul cluster services
Check out the default policies, roles, and tokens that were created

### Deploy Services to Consul's default partition and namespace
To simplify the design and test simple use cases, deploy services directly to the AKS clusters running Consul. Removing Consul Partitions (aka: remote dataplanes) and Namespaces simplifies the architecture for testing.  This section will setup services on the same AKS clusters running Consul and use the default partition and namespace.

```
cd examples/apps-server-default-default/fake-service
./deploy-consul0_consul1.sh
# Get the application URL from the script output and open in the browser

cd ../peering
./peer_consul0_to_consul1.sh
```

After verifying the service URL is healthy, refresh a couple times and pay attention to the IP Addresses serving `api` from westus2 region. Use the CLI to verify the pod IP Addresses running `api` in both westus2,and eastus regions for clarity.
```
consul0
kubectl get pods -o wide -l app=api

consul1
kubectl get pods -o wide -l app=api
```
Now that the two clusters are peered and running `api`, you can test failover from westus2 to eastus.  Switch to the westus2 cluster and apply the failover serviceresolver.
```
cd ../
consul1
kubectl apply -f fake-service/westus2/traffic-mgmt.yaml.dis
```
In the UI (consul1-westus2) go to Services->api->routing and you should see the Peer failover target (consul0-eastus).  This means everything is setup for regional failover.  Next delete the local api service running in westus2.
```
consul1
kubectl delete -f fake-service/westus2/api.yaml
```
Refresh the browser and `api` should still be responding, but from a different set of IP's.  These IP's are now coming from eastus.  This validates regional failover.  To route `web` from westus2 to eastus for all requests (no failover) update the upstream for `web` to point directly to the consul0-eastus peer's `api` service.
```
# fake-service/westus2/web.yaml

annotations:
  consul.hashicorp.com/connect-service-upstreams: 'api.svc.default.ns.consul0-eastus.peer:9091'
  #consul.hashicorp.com/connect-service-upstreams: 'api:9091'
```

After successfully testing this use case delete the deployment and mesh configurations with the following command.
```
fake-service/deploy-consul0_consul1.sh delete
```

## Deploy Consul to Agentless AKS clusters using Helm
This section will setup Consul's agentless dataplane on the remote AKS clusters so services hosted here can run within the service mesh.  In `./quickstart_multiregion` two additional AKS clusters were setup in each region (aks0, aks1) for this purpose.

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
cd consul-clients
terraform init
terraform apply -auto-approve
```
Once this is complete, you should have an agentless AKS cluster connected to Consul.  Verify the dataplane is connected to the consul cluster and healthy.  Use the `aks0` alias to switch to the first regions agentless AKS cluster.  Then use the `kc` alias to see resources in the consul namespace.  The connect-injector pod's log should show a successful connection to consul0.
```
aks0
kc get pods
kc logs $(kc get pods -l component=connect-injector -o name) | grep -i consul-server-connection-manager
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

## Deploy Services to remote AKS clusters
The Consul cluster and a remote dataplane (AKS east/west app cluster) is setup in each reagion (eastus, westus2) and ready to register services.  [Deploy example services](./examples/README.md) to test out Consul service mesh.  The script below will deploy api services in westus2 across 3 namespaces.  Each of these ns runs services within a specific Availability zone.  The `api` services will also be deployed in 1 zone in eastus.  This design will allow us to test failover across zones and regions.

```
cd ../examples/apps-dataplane-partition-ns/fake-service
./deploy-with-failover.sh
```
The application URL will be part of the output.  Copy/paste this in the brower to view the app.  This should show `web`->`api`.


Use the Consul UI tabs to verify services (`web`, `api`) are being deployed correctly.
* Datacenter (consul0-eastus)
  * Admin Partition (eastus-shared) -> Namespace (eastus-1)
    * 2 instances of `api` should be healthy
* Datacenter (consul1-westus2)
  * Admin Partition (westus2-shared) -> Namespace (westus2-1)
    * 2 instances of both `api` and `web` should be healthy
  * Admin Partition (westus2-shared) -> Namespace (westus2-2)
    * 2 instances of `api` should be healthy
  * Admin Partition (westus2-shared) -> Namespace (westus2-3)
    * 2 instances of `api` should be healthy

## Setup Peering (eastus/westus2)
Peer consul0-eastus / consul1-westus2 Consul clusters allowing services to be shared across them.  This will be used for failover.
```
cd ../peering/
./peer_aks0_to_aks1.sh
```

## Test Failover
Failover is configured using a ServiceResolver.  This was configured as part of the service deployment for the api service running in region westus2 and zone westus2-1 [westus2-1](./examples/apps-dataplane-partition-ns/fake-service/westus2/westus2-1/traffic-mgmt.yaml)
## Examples
Review [Examples](./examples/README.md) for scripts that show how to setup the UI, CLI, deploy sample apps, and other consul configurations.

## Troubleshooting

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

Download the latest helm chart source to see available values or review source in github.
```
helm show values hashicorp/consul > /tmp/consul.values
```

#### Timeout - Terraform Helm deployment
If TF release times out use helm kubectl to troubleshoot.
```
helm -n consul list  # get release name
helm -n consul history <release-name>
kubectl -n consul get pods
kubectl -n consul get svc
kubectl -n consul describe pod <name>
kubectl -n consul logs <pod>  # look at the connect-injector logs
```
#### Use latest helm chart in development
clone the hashicorp/consul-k8s repo locally to run the latest helm chart.  This is required to test the newest features not yet released or available in beta.
```
cd /tmp
git clone https://github.com/hashicorp/consul-k8s.git
```

Uninstall current helm chart release and verify the environment is clean before reinstalling
```
cd consul-primary   # cd to the cluster type that has the generated values.yaml
consul0   # switch to target K8s context
consul-k8s uninstall -auto-approve -wipe-data
kubectl -n consul get crd  #verify everything was removed
```

Edit `yaml/auto-consul0-eastus-values.yaml` with changes and reinstall.  Notice there is no helm version specified below.  Instead this release is pointing to the main branch of the consul-k8s repo cloned above.  This will have the latest development updates.  Do not use in production.
```
helm install consul0-eastus -n consul -f yaml/auto-consul0-eastus-values.yaml /tmp/consul-k8s/charts/consul
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

### Connect - Review Peer Failover Targets
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

### Get Fake Service Pod IP's
Verify the `api` pod IP `web` is routing too.
```
consul0
kubectl get pods -o wide -l app=api

consul1
kubectl get pods -o wide -l app=api
```
### Connect - Review Envoy Proxy configuration
All external traffic should be between the mesh gateways hosted in each peered region.  Review the routing for `web` and look for local and remote routes for `api`.  Verify the local mesh gateway IP and that all external routes are using this IP.
```
consul1
kc get svc consul-mesh-gateway
kubectl exec -it deploy/web -- curl localhost:19000/clusters

# Review Mesh-Gateway envoy endpoints with browser (localhost:19000)
kc port-forward deploy/consul-mesh-gateway 19000:19000
```

Revier the envoy configuration for `web`
```
consul1
kubectl exec -it deploy/web -- curl localhost:19000/config_dump
```

### Connect - Review Service Mesh defaults
Output mesh and proxy-defauls using the K8s objects
```
consul1
kubectl get proxy-defaults global -o yaml
kubectl get meshes mesh -o yaml
```

Connect to the server container and use the consul CLI to verify mesh configurations
```
consul1
kc exec consul-server-0 -- consul config read -kind proxy-defaults -name global
kc exec consul-server-0 -- consul config read -kind mesh -name mesh
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
