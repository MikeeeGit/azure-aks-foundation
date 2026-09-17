output "resource_group_name" { value = azurerm_resource_group.aks.name }
output "clusters" {
  description = "Non-secret cluster access, identity and network metadata. Obtain user credentials separately with Entra authentication."
  value = { for key, cluster in module.cluster : key => {
    id                        = cluster.id
    name                      = cluster.name
    resource_group_name       = azurerm_resource_group.aks.name
    private_fqdn              = cluster.private_fqdn
    oidc_issuer_url           = cluster.oidc_issuer_url
    control_plane_identity_id = cluster.control_plane_identity_id
    kubelet_object_id         = cluster.kubelet_object_id
    kubelet_client_id         = cluster.kubelet_client_id
    node_resource_group_name  = cluster.node_resource_group_name
    subnet_id                 = local.network.subnet_ids[var.clusters[key].subnet_key]
    subnet_cidr               = local.network.subnet_address_prefixes[var.clusters[key].subnet_key]
    kubernetes_version        = var.clusters[key].kubernetes_version
  } }
}
output "workload_identities" {
  value = { for key, identity in azurerm_user_assigned_identity.workload : key => {
    id               = identity.id
    client_id        = identity.client_id
    principal_id     = identity.principal_id
    tenant_id        = var.tenant_id
    service_accounts = var.workload_identities[key].service_accounts
  } }
}
output "ingress_handoff" {
  description = "Desired application ingress addresses for gateway configuration AFTER ingress installation and health verification. This stack does not create ingress controllers or load balancers."
  value = { for key, c in var.clusters : key => {
    private_ip            = c.ingress_private_ip
    subnet_id             = local.network.subnet_ids[c.subnet_key]
    created_by_this_stack = false
  } if c.ingress_private_ip != null }
}

output "deployment_context" {
  description = "Non-secret target binding used when exporting application delivery configuration."
  value = {
    tenant_id       = var.tenant_id
    subscription_id = var.subscription_id_map[var.subscription]
    environment     = var.environment
    region          = var.location_abbreviated
    location        = var.location
  }
}
