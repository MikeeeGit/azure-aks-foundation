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
    role_assignments = { for assignment_key, assignment in azurerm_role_assignment.workload : assignment_key => {
      id                   = assignment.id
      principal_id         = assignment.principal_id
      scope                = assignment.scope
      role_definition_name = assignment.role_definition_name
    } if local.workload_roles[assignment_key].identity == key }
    federated_credentials = { for credential_key, credential in azurerm_federated_identity_credential.workload : credential_key => {
      cluster  = local.federations[credential_key].cluster
      issuer   = credential.issuer
      subject  = credential.subject
      audience = credential.audience
    } if local.federations[credential_key].identity == key }
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

output "delivery_authorization" {
  description = "Applied non-secret CI principal and authorization bindings for the platform/bootstrap tier. Kubernetes usernames must be discovered under each real CI login, not guessed from UUIDs."
  value = {
    mode                   = var.kubernetes_authorization_mode
    admin_group_object_ids = var.entra_admin_group_object_ids
    principals             = var.delivery_principals
    targets = {
      for slot, cluster in module.cluster : slot => {
        cluster_id          = cluster.id
        cluster_name        = cluster.name
        resource_group_name = azurerm_resource_group.aks.name
      }
    }
    cluster_user_assignments = {
      for key, assignment in azurerm_role_assignment.delivery_cluster_user : key => {
        id           = assignment.id
        principal_id = assignment.principal_id
        cluster_id   = assignment.scope
      }
    }
  }
  depends_on = [azurerm_role_assignment.delivery_cluster_user, azurerm_role_assignment.native_admin_cluster_user]
}
