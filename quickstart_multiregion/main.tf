provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
resource "azurerm_resource_group" "example" {
  count    = length(var.regions)
  name     = "${var.resource_name_prefix}-${element(var.regions, count.index)}-mr"
  location = element(var.regions, count.index)
}

resource "azurerm_virtual_network" "vnet" {
  count               = length(var.regions)
  name                = "vnet-${count.index}"
  resource_group_name = element(azurerm_resource_group.example.*.name, count.index)
  address_space       = [element(var.region_cidr_list, count.index)]
  location            = element(azurerm_resource_group.example.*.location, count.index)
}

resource "azurerm_subnet" "consul" {
  count                = length(var.regions)
  name                 = "consul"
  resource_group_name  = element(azurerm_resource_group.example.*.name, count.index)
  virtual_network_name = element(azurerm_virtual_network.vnet.*.name, count.index)
  address_prefixes = [cidrsubnet(
    element(
      azurerm_virtual_network.vnet[count.index].address_space,
      count.index,
    ),
    7,
    1,
  )] # /16 + 7 = /23 or 512 IPs, netnum 1 gives the next group x.x.1.0/23

  service_endpoints = [
    "Microsoft.KeyVault",
  ]
}

# enable global peering between the two virtual network
resource "azurerm_virtual_network_peering" "peering" {
  count                        = length(var.regions)
  name                         = "peering-to-${element(azurerm_virtual_network.vnet.*.name, 1 - count.index)}"
  resource_group_name          = element(azurerm_resource_group.example.*.name, count.index)
  virtual_network_name         = element(azurerm_virtual_network.vnet.*.name, count.index)
  remote_virtual_network_id    = element(azurerm_virtual_network.vnet.*.id, 1 - count.index)
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = false
}

module "key_vault" {
  source = "../modules/key_vault/"

  common_tags          = var.common_tags
  resource_group       = azurerm_resource_group.example[0]
  resource_name_prefix = var.resource_name_prefix
}

module "aks_consul" {
  source = "../modules/aks-kubenet/"
  #source         = "../modules/aks-cni/"
  count          = length(var.regions)
  resource_group = element(azurerm_resource_group.example.*, count.index)
  aks_subnet_id  = element(azurerm_subnet.consul.*.id, count.index)
  cluster_name   = "consul${count.index}"
  node_count     = var.consul_node_count
  common_tags    = var.common_tags
}

module "aks_consul_role_assignments" {
  source           = "../modules/role_assignments/"
  count            = length(var.regions)
  aks_principal_id = element(module.aks_consul.*.aks_principal_id, count.index)
  vnet_id          = element(azurerm_virtual_network.vnet.*.id, count.index)
}

data "template_file" "consul-terraform" {
  count    = length(var.regions)
  template = file("${path.module}/templates/consul_helm_main.tmpl")
  vars = {
    azurerm_resource_group        = element(azurerm_resource_group.example.*.name, count.index)
    key_vault_name                = module.key_vault.key_vault_name
    key_vault_id                  = module.key_vault.key_vault_id
    key_vault_resource_group_name = azurerm_resource_group.example[0].name
    cluster_name                  = element(module.aks_consul.*.aks_name, count.index)
    primary                       = var.enable_cluster_peering ? 0 : count.index # set first region (index 0) to primary unless cluster peering is enabled
    datacenter                    = "${element(module.aks_consul.*.aks_name, count.index)}-${element(var.regions, count.index)}"
    release_name                  = "${element(module.aks_consul.*.aks_name, count.index)}-${element(var.regions, count.index)}"
    consul_version                = var.consul_version
    consul_helm_chart_version     = var.consul_helm_chart_version
    consul_helm_chart_template    = var.consul_helm_chart_template
    consul_chart_name             = var.consul_chart_name
    enable_cluster_peering        = var.enable_cluster_peering
    partition                     = "default"
  }
}

resource "local_file" "main" {
  count    = var.create_consul_tf ? length(var.regions) : 0
  content  = element(data.template_file.consul-terraform.*.rendered, count.index)
  filename = "${path.module}/../consul-${count.index == 0 || var.enable_cluster_peering ? "primary" : "secondary"}/auto-${element(module.aks_consul.*.aks_name, count.index)}.tf"
}
