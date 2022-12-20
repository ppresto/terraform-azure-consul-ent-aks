#!/bin/bash
SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

function dns {
    dnsIP=$(kubectl -n consul get svc consul-dns --output jsonpath='{.spec.clusterIP}')
    echo $dnsIP

    # Configure AKS coredns-custom config map with this ClusterIP.
    cat ${SCRIPT_DIR}/coredns-custom.yaml | sed "s/IPADDRESS/${dnsIP}/g" | kubectl apply -f -


    #Restart AKS coredns
    kubectl delete pod --namespace kube-system -l k8s-app=kube-dns

    #Validate Consul DNS resolution
    kubectl run busybox --restart=Never --image=busybox:1.28 -- sleep 3600
    sleep 5
    kubectl exec busybox -- nslookup consul.service.consul
}

# Default - Update K8s Contexts (consul0, consul1)
if [[ -z $1 ]]; then
    kubectl config use-context consul0
    dns
    kubectl config use-context consul1
    dns
# Input 1 context on CLI to update
elif [[ ! -z "${1}" ]]; then
    kubectl config use-context "${1}"
    dns
fi