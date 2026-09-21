data "terraform_remote_state" "network" {
  count   = var.network_remote_state == null ? 0 : 1
  backend = "azurerm"
  config  = var.network_remote_state
}
locals {
  remote_outputs = try(data.terraform_remote_state.network[0].outputs, {})
  network = var.network != null ? var.network : {
    vnet_id                 = try(local.remote_outputs.vnet_id, "")
    address_spaces          = try(local.remote_outputs.vnet.address_space, [])
    subnet_ids              = try(local.remote_outputs.subnet_ids, {})
    subnet_address_prefixes = try(local.remote_outputs.subnet_address_prefixes, {})
  }
  prefix = "${var.location_abbreviated}-${var.environment}-${var.company_abbreviation}"
  tags   = merge(var.global_tags, var.environment_tags, { Environment = var.environment, ManagedBy = "Terraform" })
  federations = { for item in flatten([for identity_key, identity in var.workload_identities : [for subject_key, sa in identity.service_accounts : [for cluster in sa.clusters : {
    key      = "${identity_key}/${subject_key}/${cluster}"
    identity = identity_key
    cluster  = cluster
    subject  = "system:serviceaccount:${sa.namespace}:${sa.service_account}"
  }]]]) : item.key => item }
  workload_roles = { for item in flatten([for identity_key, identity in var.workload_identities : [for role_key, role in identity.role_assignments : {
    key      = "${identity_key}/${role_key}"
    identity = identity_key
    scope    = role.scope
    role     = role.role_definition_name
  }]]) : item.key => item }
}
resource "azurerm_resource_group" "aks" {
  name     = "${local.prefix}-aks-rg"
  location = var.location
  tags     = local.tags
}
module "cluster" {
  for_each                      = var.clusters
  source                        = "./modules/cluster"
  name                          = "${local.prefix}-${each.key}"
  resource_group_name           = azurerm_resource_group.aks.name
  location                      = var.location
  tenant_id                     = var.tenant_id
  cluster                       = each.value
  vnet_id                       = local.network.vnet_id
  subnet_id                     = try(local.network.subnet_ids[each.value.subnet_key], "")
  private_dns_zone_id           = var.private_dns_zone_id
  log_analytics_workspace_id    = var.log_analytics_workspace_id
  cluster_admin_principal_ids   = var.cluster_admin_principal_ids
  kubernetes_authorization_mode = var.kubernetes_authorization_mode
  entra_admin_group_object_ids  = var.entra_admin_group_object_ids
  acr_registries                = var.acr_registries
  tags                          = local.tags
  depends_on                    = [terraform_data.network_contract, terraform_data.delivery_contract]
}
resource "azurerm_user_assigned_identity" "workload" {
  for_each            = var.workload_identities
  name                = "${local.prefix}-${each.key}-workload"
  location            = var.location
  resource_group_name = azurerm_resource_group.aks.name
  tags                = local.tags
}
resource "azurerm_federated_identity_credential" "workload" {
  for_each            = local.federations
  name                = "aks-${substr(sha256(each.key), 0, 24)}"
  resource_group_name = azurerm_resource_group.aks.name
  parent_id           = azurerm_user_assigned_identity.workload[each.value.identity].id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.cluster[each.value.cluster].oidc_issuer_url
  subject             = each.value.subject
}
resource "azurerm_role_assignment" "workload" {
  for_each                         = local.workload_roles
  scope                            = each.value.scope
  role_definition_name             = each.value.role
  principal_id                     = azurerm_user_assigned_identity.workload[each.value.identity].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
