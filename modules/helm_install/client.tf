/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

resource "helm_release" "consul_client" {
  count            = var.client && var.enable_cluster_peering ? 1 : 0
  chart            = var.chart_name
  create_namespace = var.create_namespace
  name             = var.release_name
  namespace        = var.kubernetes_namespace
  repository       = var.chart_repository
  timeout          = 900
  version          = var.consul_helm_chart_version

  values = [data.template_file.consul-client[0].rendered]
  depends_on = [kubernetes_namespace.consul]
}
data "template_file" "consul-client" {
  count    = var.client && var.enable_cluster_peering ? 1 : 0
  template = file("${path.module}/templates/${var.consul_helm_chart_template}")
  vars = {
    consul_version  = var.consul_version
    server_replicas = var.server_replicas
    cluster_name    = var.cluster_name
    datacenter      = var.datacenter
    partition       = var.consul_partition
    aks_cluster     = data.azurerm_kubernetes_cluster.cluster.kube_config.0.host
    consul_external_servers = var.consul_external_servers
  }
}
resource "local_file" "consul-client" {
  count    = var.client && var.enable_cluster_peering ? 1 : 0
  content  = data.template_file.consul-client[0].rendered
  filename = "./yaml/auto-${var.release_name}-values.yaml"
}

resource "kubernetes_secret" "consul_license_client" {
  count = var.client && var.enable_cluster_peering ? 1 : 0
  metadata {
    name      = "consul-ent-license"
    namespace = var.kubernetes_namespace
  }

  data = {
    "key" = var.consul_license
  }
}

# Get Consul Cluster CA Certificate
data "azurerm_key_vault" "consul-ca-cert" {
  count               = var.client && var.enable_cluster_peering ? 1 : 0
  name                = var.azure_key_vault_name
  resource_group_name = var.key_vault_resource_group_name
}

data "azurerm_key_vault_secret" "consul-ca-cert" {
  count        = var.client && var.enable_cluster_peering ? 1 : 0
  name         = "${var.datacenter}-ca-cert"
  key_vault_id = data.azurerm_key_vault.consul-ca-cert[0].id
}

resource "kubernetes_secret" "consul-ca-cert" {
  count = var.client && var.enable_cluster_peering ? 1 : 0
  metadata {
    name      = "consul-ca-cert"
    namespace = var.kubernetes_namespace
  }

  data = jsondecode(data.azurerm_key_vault_secret.consul-ca-cert[0].value)
  depends_on = [
    data.azurerm_key_vault_secret.consul-ca-cert[0]
  ]
}

# Get Consul Cluster bootstrap token
data "azurerm_key_vault" "consul-bootstrap-token" {
  count               = var.client && var.enable_cluster_peering ? 1 : 0
  name                = var.azure_key_vault_name
  resource_group_name = var.key_vault_resource_group_name
}

data "azurerm_key_vault_secret" "consul-bootstrap-token" {
  count        = var.client && var.enable_cluster_peering ? 1 : 0
  name         = "${var.datacenter}-bootstrap-token"
  key_vault_id = data.azurerm_key_vault.consul-bootstrap-token[0].id
}

resource "kubernetes_secret" "consul-bootstrap-token" {
  count = var.client && var.enable_cluster_peering ? 1 : 0
  metadata {
    name      = "consul-bootstrap-acl-token"
    namespace = var.kubernetes_namespace
  }

  data = jsondecode(data.azurerm_key_vault_secret.consul-bootstrap-token[0].value)
  depends_on = [
    data.azurerm_key_vault_secret.consul-bootstrap-token[0]
  ]
}