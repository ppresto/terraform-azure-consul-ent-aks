/**
 * Copyright © 2014-2022 HashiCorp, Inc.
 *
 * This Source Code is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this project, you can obtain one at http://mozilla.org/MPL/2.0/.
 *
 */

# Role assignment to be able to manage the virtual network
resource "azurerm_role_assignment" "aks_vnet_contributor_aks1" {
  scope                            = var.vnet_id
  role_definition_name             = "Contributor"
  principal_id                     = var.aks_principal_id
  skip_service_principal_aad_check = true
}