output "id" { value = azurerm_kubernetes_cluster.this.id }
output "name" { value = azurerm_kubernetes_cluster.this.name }
output "private_fqdn" { value = azurerm_kubernetes_cluster.this.private_fqdn }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.this.oidc_issuer_url }
output "control_plane_identity_id" { value = azurerm_user_assigned_identity.control_plane.id }
output "kubelet_object_id" { value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id }
output "kubelet_client_id" { value = azurerm_kubernetes_cluster.this.kubelet_identity[0].client_id }
output "node_resource_group_name" { value = azurerm_kubernetes_cluster.this.node_resource_group }

output "system_pool" {
  description = "Applied non-secret system pool settings for capacity and scheduling review."
  value = {
    vm_size                      = azurerm_kubernetes_cluster.this.default_node_pool[0].vm_size
    node_count                   = azurerm_kubernetes_cluster.this.default_node_pool[0].node_count
    min_count                    = azurerm_kubernetes_cluster.this.default_node_pool[0].min_count
    max_count                    = azurerm_kubernetes_cluster.this.default_node_pool[0].max_count
    only_critical_addons_enabled = azurerm_kubernetes_cluster.this.default_node_pool[0].only_critical_addons_enabled
    host_encryption_enabled      = azurerm_kubernetes_cluster.this.default_node_pool[0].host_encryption_enabled
    max_surge                    = azurerm_kubernetes_cluster.this.default_node_pool[0].upgrade_settings[0].max_surge
  }
}
output "user_pool_count" { value = length(azurerm_kubernetes_cluster_node_pool.user) }
output "sku_tier" { value = azurerm_kubernetes_cluster.this.sku_tier }
