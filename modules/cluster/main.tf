resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "${var.name}-control-plane"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_user_assigned_identity" "kubelet" {
  name                = "${var.name}-kubelet"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}
resource "azurerm_role_assignment" "kubelet_operator" {
  scope                            = azurerm_user_assigned_identity.kubelet.id
  role_definition_name             = "Managed Identity Operator"
  principal_id                     = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "network" {
  scope                            = var.vnet_id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "private_dns" {
  count                            = var.private_dns_zone_id == "System" ? 0 : 1
  scope                            = var.private_dns_zone_id
  role_definition_name             = "Private DNS Zone Contributor"
  principal_id                     = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
resource "azurerm_role_assignment" "route_table" {
  count                            = var.cluster.outbound_type == "userDefinedRouting" ? 1 : 0
  scope                            = var.cluster.route_table_id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.control_plane.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
resource "azurerm_kubernetes_cluster" "this" {
  name                                = var.name
  location                            = var.location
  resource_group_name                 = var.resource_group_name
  kubernetes_version                  = var.cluster.kubernetes_version
  dns_prefix_private_cluster          = var.private_dns_zone_id == "System" ? null : var.name
  dns_prefix                          = var.private_dns_zone_id == "System" ? var.name : null
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  private_dns_zone_id                 = var.private_dns_zone_id
  local_account_disabled              = true
  run_command_enabled                 = false
  role_based_access_control_enabled   = true
  azure_policy_enabled                = true
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true
  sku_tier                            = var.cluster.sku_tier
  node_os_upgrade_channel             = "NodeImage"
  tags                                = var.tags
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }
  kubelet_identity {
    client_id                 = azurerm_user_assigned_identity.kubelet.client_id
    object_id                 = azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id = azurerm_user_assigned_identity.kubelet.id
  }
  azure_active_directory_role_based_access_control {
    tenant_id              = var.tenant_id
    azure_rbac_enabled     = var.kubernetes_authorization_mode == "azure_rbac"
    admin_group_object_ids = var.kubernetes_authorization_mode == "kubernetes_rbac" ? var.entra_admin_group_object_ids : null
  }
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = var.cluster.outbound_type
    pod_cidr            = var.cluster.pod_cidr
    service_cidr        = var.cluster.service_cidr
    dns_service_ip      = var.cluster.dns_service_ip
  }
  default_node_pool {
    name                         = "systemnp"
    vm_size                      = var.cluster.system_pool.vm_size
    vnet_subnet_id               = var.subnet_id
    type                         = "VirtualMachineScaleSets"
    node_count                   = var.cluster.system_pool.min_count == null ? var.cluster.system_pool.node_count : null
    auto_scaling_enabled         = var.cluster.system_pool.min_count != null
    min_count                    = var.cluster.system_pool.min_count
    max_count                    = var.cluster.system_pool.max_count
    max_pods                     = var.cluster.system_pool.max_pods
    os_disk_size_gb              = var.cluster.system_pool.os_disk_size_gb
    os_sku                       = var.cluster.os_sku
    zones                        = var.cluster.system_pool.zones
    only_critical_addons_enabled = true
    node_public_ip_enabled       = false
    host_encryption_enabled      = var.cluster.system_pool.host_encryption_enabled
    temporary_name_for_rotation  = "systemrot"
    tags                         = var.tags
    upgrade_settings {
      max_surge                     = "10%"
      drain_timeout_in_minutes      = 30
      node_soak_duration_in_minutes = 5
    }
  }
  auto_scaler_profile {
    balance_similar_node_groups      = var.cluster.autoscaler_profile.balance_similar_node_groups
    expander                         = var.cluster.autoscaler_profile.expander
    max_graceful_termination_sec     = var.cluster.autoscaler_profile.max_graceful_termination_sec
    max_node_provisioning_time       = var.cluster.autoscaler_profile.max_node_provisioning_time
    max_unready_nodes                = var.cluster.autoscaler_profile.max_unready_nodes
    max_unready_percentage           = var.cluster.autoscaler_profile.max_unready_percentage
    scale_down_delay_after_add       = var.cluster.autoscaler_profile.scale_down_delay_after_add
    scale_down_unneeded              = var.cluster.autoscaler_profile.scale_down_unneeded
    scan_interval                    = var.cluster.autoscaler_profile.scan_interval
    skip_nodes_with_local_storage    = var.cluster.autoscaler_profile.skip_nodes_with_local_storage
    skip_nodes_with_system_pods      = var.cluster.autoscaler_profile.skip_nodes_with_system_pods
    scale_down_utilization_threshold = var.cluster.autoscaler_profile.scale_down_utilization_threshold
  }
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id == null ? [] : [var.log_analytics_workspace_id]
    content {
      log_analytics_workspace_id      = oms_agent.value
      msi_auth_for_monitoring_enabled = true
    }
  }
  depends_on = [azurerm_role_assignment.network, azurerm_role_assignment.private_dns, azurerm_role_assignment.route_table, azurerm_role_assignment.kubelet_operator]
}
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  for_each                    = var.cluster.user_pools
  name                        = each.key
  kubernetes_cluster_id       = azurerm_kubernetes_cluster.this.id
  vm_size                     = each.value.vm_size
  vnet_subnet_id              = var.subnet_id
  mode                        = "User"
  os_type                     = "Linux"
  os_sku                      = var.cluster.os_sku
  orchestrator_version        = var.cluster.kubernetes_version
  node_count                  = each.value.min_count == null ? each.value.node_count : null
  auto_scaling_enabled        = each.value.min_count != null
  min_count                   = each.value.min_count
  max_count                   = each.value.max_count
  max_pods                    = each.value.max_pods
  os_disk_size_gb             = each.value.os_disk_size_gb
  host_encryption_enabled     = each.value.host_encryption_enabled
  node_public_ip_enabled      = false
  zones                       = each.value.zones
  node_labels                 = each.value.node_labels
  node_taints                 = each.value.node_taints
  temporary_name_for_rotation = "${each.key}r"
  tags                        = var.tags
  upgrade_settings {
    max_surge                     = "10%"
    drain_timeout_in_minutes      = 30
    node_soak_duration_in_minutes = 5
  }
}
resource "azurerm_role_assignment" "cluster_admin" {
  for_each             = var.cluster_admin_principal_ids
  scope                = azurerm_kubernetes_cluster.this.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = each.value
}
resource "azurerm_role_assignment" "acr_pull" {
  for_each                         = var.acr_registries
  scope                            = each.value.id
  role_definition_name             = each.value.pull_role
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}
resource "azurerm_monitor_diagnostic_setting" "this" {
  count                          = var.log_analytics_workspace_id == null ? 0 : 1
  name                           = "${var.name}-diagnostics"
  target_resource_id             = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"
  enabled_log { category_group = "allLogs" }
  enabled_metric { category = "AllMetrics" }
}
