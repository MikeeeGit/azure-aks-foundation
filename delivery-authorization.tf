locals {
  delivery_cluster_grants = {
    for grant in flatten([
      for key, identity in var.delivery_principals : [
        for slot in identity.clusters : {
          key          = "${key}/${slot}"
          identity_key = key
          slot         = slot
          principal_id = identity.principal_id
          purpose      = identity.purpose
        }
      ]
    ]) : grant.key => grant
  }
  native_admin_cluster_grants = {
    for grant in flatten([
      for group in var.entra_admin_group_object_ids : [
        for slot in keys(var.clusters) : {
          key          = "${lower(group)}/${slot}"
          slot         = slot
          principal_id = group
        }
      ]
    ]) : grant.key => grant
  }
}

# Cluster User permits Entra user kubeconfig retrieval, not Kubernetes API writes.
resource "azurerm_role_assignment" "delivery_cluster_user" {
  for_each                         = local.delivery_cluster_grants
  name                             = uuidv5("url", join("|", [lower(module.cluster[each.value.slot].id), lower(each.value.principal_id), "4abbcc35-e782-43d8-92c5-2d3f1bd2253f"]))
  scope                            = module.cluster[each.value.slot].id
  role_definition_name             = "Azure Kubernetes Service Cluster User Role"
  principal_id                     = each.value.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "native_admin_cluster_user" {
  for_each             = local.native_admin_cluster_grants
  scope                = module.cluster[each.value.slot].id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = each.value.principal_id
  principal_type       = "Group"
}
