# Create 1 App Subnet in each region

resource "azurerm_subnet" "apps" {
  count                = length(var.regions)
  name                 = "apps"
  resource_group_name  = element(azurerm_resource_group.example.*.name, count.index)
  virtual_network_name = element(azurerm_virtual_network.vnet.*.name, count.index)
  address_prefixes = [cidrsubnet(
    element(
      azurerm_virtual_network.vnet[count.index].address_space,
      count.index,
    ),
    7,
    3,
  )] # /16 + 7 = /23 or 256 IPs, netnum 3 skips first 2 groups used by consul.

  service_endpoints = [
    "Microsoft.KeyVault",
  ]
}

# Create 1 AKS cluster in each apps subnet
module "aks_apps" {
  source         = "../modules/aks-kubenet/"
  count          = length(azurerm_subnet.apps.*.id)
  resource_group = element(azurerm_resource_group.example.*, count.index)
  aks_subnet_id  = element(azurerm_subnet.apps.*.id, count.index)
  cluster_name   = "aks${count.index}"
  node_count     = 3
  vm_size        = "Standard_D2s_v3"
  zones          = ["1", "2", "3"]
  common_tags    = var.common_tags

  #depends_on = [
  #  # vnet module creates additional network resources that aks depends on
  #  azurerm_virtual_network.vnet,
  #]
}

module "aks_apps_role_assignments" {
  source           = "../modules/role_assignments/"
  count            = length(var.regions)
  aks_principal_id = element(module.aks_apps.*.aks_principal_id, count.index)
  vnet_id          = element(azurerm_virtual_network.vnet.*.id, count.index)
}

data "template_file" "secondary" {
  # if cluster_peering is false then assume all clients are secondary consul servers
  count    = var.enable_cluster_peering ? 0 : length(module.aks_apps.*.aks_name)
  template = file("${path.module}/templates/consul_helm_main.tmpl")
  vars = {
    azurerm_resource_group        = element(azurerm_resource_group.example.*.name, count.index)
    key_vault_name                = module.key_vault.key_vault_name
    key_vault_id                  = module.key_vault.key_vault_id
    key_vault_resource_group_name = azurerm_resource_group.example[0].name
    cluster_name                  = element(module.aks_apps.*.aks_name, count.index)
    datacenter                    = "${element(module.aks_consul.*.aks_name, count.index)}-${element(var.regions, count.index)}"
    release_name                  = "${element(module.aks_apps.*.aks_name, count.index)}-${element(var.regions, count.index)}"
    primary                       = var.enable_cluster_peering ? 0 : 1 # set index 1 to be a secondary consul cluster for WAN Fed.  Cluster Peering requires all clusters to be primary
    consul_version                = var.consul_version
    consul_helm_chart_version     = var.consul_helm_chart_version
    consul_helm_chart_template     = var.consul_helm_chart_template
    consul_chart_name             = var.consul_chart_name
    enable_cluster_peering        = var.enable_cluster_peering
  }
}
resource "local_file" "secondary-tf" {
  count    = var.create_consul_tf && var.enable_cluster_peering == false ? length(module.aks_apps.*.aks_name) : 0
  content  = element(data.template_file.secondary.*.rendered, count.index)
  filename = "${path.module}/../consul-secondary/auto-${element(module.aks_apps.*.aks_name, count.index)}.tf"
}

data "template_file" "clients" {
  # If cluster peering is enabled assume bootstrap app clusters to dataplane
  count    = var.enable_cluster_peering ? length(module.aks_apps.*.aks_name) : 0
  template = file("${path.module}/templates/consul_helm_client.tmpl")
  vars = {
    azurerm_resource_group        = element(azurerm_resource_group.example.*.name, count.index)
    key_vault_name                = module.key_vault.key_vault_name
    key_vault_id                  = module.key_vault.key_vault_id
    key_vault_resource_group_name = azurerm_resource_group.example[0].name
    cluster_name                  = element(module.aks_apps.*.aks_name, count.index)
    datacenter                    = "${element(module.aks_consul.*.aks_name, count.index)}-${element(var.regions, count.index)}"
    release_name                  = "${element(module.aks_apps.*.aks_name, count.index)}-${element(var.regions, count.index)}"
    primary                       = 0
    consul_version                = var.consul_version
    consul_helm_chart_version     = var.consul_helm_chart_version
    consul_helm_chart_template    = var.consul_client_helm_chart_template
    consul_chart_name             = var.consul_chart_name
    enable_cluster_peering        = var.enable_cluster_peering
  }
}
resource "local_file" "client-tf" {
  count    = var.create_consul_tf && var.enable_cluster_peering ? length(module.aks_apps.*.aks_name) : 0
  content  = element(data.template_file.clients.*.rendered, count.index)
  filename = "${path.module}/../consul-clients/auto-${element(module.aks_apps.*.aks_name, count.index)}.tf"
}