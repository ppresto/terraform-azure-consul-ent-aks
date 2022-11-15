/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

data "azurerm_client_config" "current" {}
data "azurerm_kubernetes_cluster" "cluster" {
  name                = var.cluster_name
  resource_group_name = var.resource_group_name
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
  token                  = data.azurerm_kubernetes_cluster.cluster.kube_config.0.password
}

resource "kubernetes_namespace" "consul" {
  metadata {
    name = var.kubernetes_namespace
  }
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
    token                  = data.azurerm_kubernetes_cluster.cluster.kube_config.0.password
  }
}

#provider "consul" {
#  address    = hcp_consul_cluster.example_hcp.consul_public_endpoint_url
#  datacenter = hcp_consul_cluster.example_hcp.datacenter
#  token      = hcp_consul_cluster_root_token.init.secret_id
#}

provider "kubectl" {
  host                   = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate)
  token                  = data.azurerm_kubernetes_cluster.cluster.kube_config.0.password
  load_config_file       = false
}