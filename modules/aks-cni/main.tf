/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

resource "azurerm_kubernetes_cluster" "cluster" {
  name                = var.cluster_name
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  dns_prefix          = "aks"
  #private_cluster_enabled = true

  default_node_pool {
    name                         = "default"
    node_count                   = 3
    only_critical_addons_enabled = true
    vm_size                      = "Standard_D2s_v3"
    vnet_subnet_id               = var.aks_subnet_id
    zones                        = ["1", "2", "3"]
  }

  network_profile {
    network_plugin = "azure"
    network_mode   = "transparent"
    #network_policy     = "azure"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.common_tags
}

resource "azurerm_kubernetes_cluster_node_pool" "cluster" {
  name                  = var.name
  kubernetes_cluster_id = azurerm_kubernetes_cluster.cluster.id
  vm_size               = var.vm_size
  node_count            = var.node_count
  vnet_subnet_id        = var.aks_subnet_id
  zones                 = var.zones

  tags = var.common_tags
}
