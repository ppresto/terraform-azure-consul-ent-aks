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

## ./apps-
Theser directories contain example yaml to deploy the [Fake Service](https://github.com/nicholasjackson/fake-service). This is a test service that can handle both HTTP and gRPC traffic, for testing upstream service communications and other service mesh scenarios.  In addition, these directories contain scripts to setup Peering.  These directories contain everything needed to support the following use cases.
* Failover across East/West Peered Consul datacenters using default AP and default NS.
* Failover across East/West Remote Agentless AKS clusters registered with a custom AP and NS
* Failover across East/West WAN Federated datacenters
