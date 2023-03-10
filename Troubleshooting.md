# Troubleshooting Consul Enterprise on AKS
<!-- TOC -->

- [Troubleshooting Consul Enterprise on AKS](#troubleshooting-consul-enterprise-on-aks)
  - [DNS AKS coredns](#dns-aks-coredns)
    - [DNS Consul](#dns-consul)
  - [Helm](#helm)
    - [Uninstall](#uninstall)
    - [Use hashicorp/consul-k8s main branch (latest development)](#use-hashicorpconsul-k8s-main-branch-latest-development)
    - [Manually Install Consul Dataplane on remote AKS Cluster](#manually-install-consul-dataplane-on-remote-aks-cluster)
  - [CA Cert](#ca-cert)
  - [Connect - Peer Failover Targets](#connect---peer-failover-targets)

<!-- /TOC -->

## DNS AKS coredns
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

## Helm
When troubleshooting or trying out new helm chart values you may want to manually use helm to install, upgrade, or delete Consul.  After running terraform to manage the helm install auto-* files will be created with the helm values used by terraform.  You can use these files to see exactly what values were used and to manually uninstall and upgrade Consul config as needed.
```
./consul-primary/yaml/
./consul-secondary/yaml/
./consul-clients/yaml/
```
You can also review `./consul-secondary/yaml/manual_install.sh` for tips to setup helm repo, copy k8s secrets from one cluster to another and install consul.

### Uninstall
Uninstall the helm chart and verify the environment is clean before reinstalling
```
# use consul-k8s CLI for clean uninstall and PVC deletion.
consul-k8s uninstall -auto-approve -wipe-data
```

If helm uninstall was used and failed or TF release times out use helm kubectl to troubleshoot.
```
helm -n consul list  # get release name
helm -n consul history <release-name>
kubectl -n consul get pods
kubectl -n consul get svc
kubectl -n consul describe pod <name>
kubectl -n consul logs <pod>
```

### Use hashicorp/consul-k8s main branch (latest development)
Clone the hashicorp/consul-k8s repo locally to run the latest helm chart.  This is required to test the newest features not yet released or available in beta.

consul0
```
cd consul-primary
terraform init
terraform apply -auto-approve
```

Edit `yaml/auto-consul0-eastus-values.yaml` with changes and test install.
```
helm install consul0-eastus -n consul -f yaml/auto-consul0-eastus-values.yaml /Users/patrickpresto/Projects/consul/consul-k8s/charts/consul
```

### Manually Install Consul Dataplane on remote AKS Cluster
This repo will create 1 client cluster per region by default.  Connect to your client cluster with kubectl.  The default contexts are `aks0, aks1`, 1 for each region.  These client clusters require a boostrap token and CA cert from the primary Consul cluster so copy those over to the dataplane before installation.

```
aks0
kubectl create ns consul

kubectl -n consul get secret consul-bootstrap-acl-token --context consul0 -o yaml \
| kubectl apply --context aks0 -f -

kubectl -n consul get secret consul-ca-cert --context consul0 -o yaml \
| kubectl apply --context aks0 -f -

helm -n consul install aks0-eastus hashicorp/consul --version 1.0.2 -f yaml/auto-aks0-eastus-values.yaml
helm -n consul install aks0-eastus hashicorp/consul --version 1.0.2 -f yaml/auto-aks0-eastus-values.yaml
# helm -n consul uninstall aks0-eastus
# consul-k8s uninstall -auto-approve -wipe-data
```

## CA Cert

Use openssl to view a cert in k8s secrets.
```
kubectl get secret -n consul consul-ca-cert -o jsonpath="{.data['tls\.crt']}" | base64 --decode | openssl x509 -text -noout
```

## Connect - Peer Failover Targets

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
