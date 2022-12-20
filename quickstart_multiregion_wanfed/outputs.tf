/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */


output "regions" {
  value = azurerm_resource_group.example.*.location
}
output "resource_groups" {
  value = azurerm_resource_group.example.*.name
}

output "aks_consul_clusters" {
  value = module.aks_consul.*.aks_name
}

output "aks_app_clusters" {
  value = module.aks_apps.*.aks_name
}

output "key_vault_id" {
  value = module.key_vault.key_vault_id
}

output "key_vault_name" {
  value = module.key_vault.key_vault_name
}

output "auth_to_aks_consul_clusters" {
  value = [for n in module.aks_consul.* : replace(n.node_resource_group, "/.*_(.*)_(.*)_.*/", "az aks get-credentials --resource-group $1 --name $2")]
}

output "auth_to_aks_apps_clusters" {
  value = [for n in module.aks_apps.* : replace(n.node_resource_group, "/.*_(.*)_(.*)_.*/", "az aks get-credentials --resource-group $1 --name $2")]
}