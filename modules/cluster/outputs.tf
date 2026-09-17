output "id" { value = azurerm_kubernetes_cluster.this.id }
output "name" { value = azurerm_kubernetes_cluster.this.name }
output "private_fqdn" { value = azurerm_kubernetes_cluster.this.private_fqdn }
output "oidc_issuer_url" { value = azurerm_kubernetes_cluster.this.oidc_issuer_url }
output "control_plane_identity_id" { value = azurerm_user_assigned_identity.control_plane.id }
output "kubelet_object_id" { value = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id }
output "kubelet_client_id" { value = azurerm_kubernetes_cluster.this.kubelet_identity[0].client_id }
output "node_resource_group_name" { value = azurerm_kubernetes_cluster.this.node_resource_group }
