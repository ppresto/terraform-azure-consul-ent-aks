/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

variable "regions" {
  default = [
    "eastus",
    "westus2",
  ]
}

variable "region_cidr_list" {
  default = [
    "172.16.0.0/16",
    "172.17.0.0/16",
  ]
}


variable "common_tags" {
  default     = {}
  description = "(Optional) Map of common tags for all taggable resources"
  type        = map(string)
}

variable "resource_name_prefix" {
  description = "Prefix for resource names (e.g. \"prod\")"
  type        = string

  # azurerm_key_vault name must not exceed 24 characters and has this as a prefix
  validation {
    condition     = length(var.resource_name_prefix) < 12 && (replace(var.resource_name_prefix, " ", "") == var.resource_name_prefix)
    error_message = "The resource_name_prefix value must be fewer than 12 characters and may not contain spaces."
  }
}

variable "create_consul_tf" {
  description = "Automatically create both consul primary and secondary cluster terraform files in ./consul-primery, ./consul-secondary directories"
  default     = true
}

variable "consul_node_count" {
  description = "Consul Cluster AKS Node Count"
  #default     = 5
  default     = 3
}

variable "consul_version" {
  description = "Consul Version"
  default     = "1.11.5"
}

variable "consul_helm_chart_version" {
  default     = "1.14.0"
}
variable "consul_helm_chart_template" {
  description = "Consul Version depends on the helm chart version. Select helm chart version."
  # Supported Versions
  # default = "0.41.0" - WAN Federation
  # default = "1.13.3" - Cluster Peering
  default     = "values-peer-cluster.yaml"
}
variable "consul_client_helm_chart_template" {
  description = "Select helm chart template."
  # Supported Versions
  # default = "0.41.0" - WAN Federation
  default     = "values-client-aks.yaml"
}
variable "consul_chart_name" {
  description = "Consul chart name"
  # Supported Versions
  # default = "consul"
  default     = "consul"
}
variable "enable_cluster_peering" {
  description = "Set this variable to true if you want to setup all Consul clusters as primaries that support cluster peering"
  default     = true
}
variable "client" {
  description = "consul client only"
  default     = false
}