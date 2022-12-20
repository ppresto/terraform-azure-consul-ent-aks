/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

variable "azure_key_vault_id" {
  type        = string
  description = "ID of Azure key vault that will store Consul federation data"
}

variable "azure_key_vault_name" {
  type        = string
  description = "Name of Azure Key Vault that will store Consul federation data"
}

variable "azure_key_vault_secret_name" {
  type        = string
  default     = "federationsecret"
  description = "Name of Azure key vault secret holding Consul federation data"
}

variable "chart_name" {
  type        = string
  default     = "consul"
  description = "Chart name to be installed"
}

variable "chart_repository" {
  type        = string
  default     = "https://helm.releases.hashicorp.com"
  description = "Repository URL where to locate the requested chart"
}

variable "cluster_name" {
  type        = string
  description = "Name of AKS cluster"
}

variable "consul_helm_chart_version" {
  type        = string
  description = "Version of Consul helm chart."
  # Changing this version may break the reliability
  # of Consul installation and federation
  # Supported Versions
  # default = "0.41.0" - WAN Federation
  # default = "1.13.3" - Cluster Peering
  default = "0.41.0"
}
variable "consul_helm_chart_template" {
  description = "Select helm chart template."
  # Supported Versions
  # default = "0.41.0" - WAN Federation
  #default     = "0.41.1"
}

variable "consul_client_helm_chart_template" {
  description = "Select helm chart template."
  # Supported Versions
  # default = "0.41.0" - WAN Federation
  default = ""
}

variable "consul_version" {
  type        = string
  description = "Version of Consul Enterprise to install"
  default     = "1.11.5"
}

variable "consul_license" {
  type        = string
  description = "Consul license"
}

variable "consul_namespace" {
  type        = string
  default     = "consul"
  description = "The namespace to install the release into"
}
variable "consul_partition" {
  type        = string
  default     = "default"
  description = "The partition to install the release into"
}
variable "create_namespace" {
  type        = bool
  default     = true
  description = "Create the k8s namespace if it does not yet exist"
}

variable "kubernetes_namespace" {
  type        = string
  default     = "consul"
  description = "The namespace to install the k8s resources into"
}

variable "primary_datacenter" {
  type        = bool
  description = "If true, installs Consul with a primary datacenter configuration. Set to false for secondary datacenters"
}

variable "enable_cluster_peering" {
  description = "Set this variable to true if you want to setup all Consul clusters as primaries that support cluster peering"
  default     = false
}
variable "client" {
  description = "Set this variable to true to bootstrap aks cluster to consul"
  default     = false
}
variable "consul_external_servers" {
  description = "agents need the consul cluster location"
  default     = ""
}

variable "release_name" {
  type        = string
  default     = "consul-release"
  description = "The helm release name"
}
variable "datacenter" {
  type        = string
  default     = "consul datacenter"
  description = "dc1"
}
variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "key_vault_resource_group_name" {
  description = "Resource group name where key_vault lives if different then current VNET"
  type        = string
}
variable "server_replicas" {
  type        = number
  default     = 5
  description = "The number of Consul server replicas"
}
