#!/bin/bash

SCRIPT_DIR=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

output=$(terraform output -json)
consul=($(echo $output | jq -r '.aks_consul_clusters.value[]'))
aks=($(echo $output | jq -r '.aks_app_clusters.value[]'))
rg=($(echo $output | jq -r '.resource_groups.value[]'))
regions=($(echo $output | jq -r '.regions.value[]'))

echo "Connect to the target AKS cluster using the following Command"
# the ! returns the array indices
for i in ${!rg[@]}
do
    az aks get-credentials --resource-group ${rg[$i]} --name ${consul[$i]} --overwrite-existing
    az aks get-credentials --resource-group ${rg[$i]} --name ${aks[$i]} --overwrite-existing
    alias $(echo ${consul[$i]})="kubectl config use-context ${consul[$i]}; echo ${consul[$i]}-${regions[$i]}"
    alias $(echo ${aks[$i]})="kubectl config use-context ${aks[$i]}; echo ${aks[$i]}-${regions[$i]}"

    alias kc="kubectl -n consul"
    alias $(echo k${regions[$i]:0:1}1)="kubectl -n ${regions[$i]}-1"
    alias $(echo k${regions[$i]:0:1}2)="kubectl -n ${regions[$i]}-2"
    alias $(echo k${regions[$i]:0:1}3)="kubectl -n ${regions[$i]}-3"
done

echo
echo "Source this script to import the following Alias into your shell"
echo
for i in ${!regions[@]}
do
    echo
    echo "### Region: ${regions[$i]}"
    echo -e "\tAKS Context Aliases"
    echo -e "\t\t${consul[$i]}\t- kubectl config use-context ${consul[$i]}"
    echo -e "\t\t${aks[$i]}\t- kubectl config use-context ${aks[$i]}"
    echo -e "\tNamespace Alias"
    echo -e "\t\tk${regions[$i]:0:1}1 - kubectl -n ${regions[$i]}-1" 
    echo -e "\t\tk${regions[$i]:0:1}2 - kubectl -n ${regions[$i]}-2" 
    echo -e "\t\tk${regions[$i]:0:1}3 - kubectl -n ${regions[$i]}-3" 
    echo -e "\t\tkc - kubectl -n consul" 
    
done
