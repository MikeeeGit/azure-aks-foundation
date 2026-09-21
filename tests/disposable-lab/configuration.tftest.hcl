mock_provider "azurerm" {
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/mock-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mock"
      principal_id = "00000000-0000-0000-0000-000000000005"
      client_id    = "00000000-0000-0000-0000-000000000006"
    }
  }
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/mock-rg/providers/Microsoft.ContainerService/managedClusters/mock"
      oidc_issuer_url     = "https://uksouth.oic.prod-aks.azure.com/example/issuer/"
      private_fqdn        = "mock.privatelink.uksouth.azmk8s.io"
      node_resource_group = "mock-nodes-rg"
      kubelet_identity    = [{ client_id = "00000000-0000-0000-0000-000000000007", object_id = "00000000-0000-0000-0000-000000000008", user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/mock-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/kubelet" }]
    }
  }
}

run "both_lab_slots_preserve_capacity_and_explicit_scheduling" {
  command = plan
  assert {
    condition     = toset(keys(output.clusters)) == toset(["aks01", "aks02"])
    error_message = "The disposable lab must contain both independent slots."
  }
  assert {
    condition     = alltrue([for cluster in values(output.clusters) : cluster.system_pool.node_count == 2 && cluster.system_pool.vm_size == "Standard_D4s_v4" && !cluster.system_pool.only_critical_addons_enabled && cluster.user_pool_count == 0])
    error_message = "Both actual module outputs must expose two D4 system nodes, explicit mixed scheduling and no user pools."
  }
  assert {
    condition     = alltrue([for cluster in values(output.clusters) : cluster.sku_tier == "Free" && cluster.system_pool.host_encryption_enabled && cluster.system_pool.max_surge == "10%"])
    error_message = "Both slots must preserve encryption and the planned upgrade-surge contract."
  }
  assert {
    condition     = output.delivery_authorization.mode == "kubernetes_rbac" && length(output.delivery_authorization.admin_group_object_ids) == 1
    error_message = "The lab must retain its explicit managed-Entra native authorization profile."
  }
}
