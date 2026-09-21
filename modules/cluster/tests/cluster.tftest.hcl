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

variables {
  name                = "uks-pprd-example-aks01"
  resource_group_name = "example-aks-rg"
  location            = "uksouth"
  tenant_id           = "00000000-0000-0000-0000-000000000001"
  vnet_id             = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-example-vnet-rg/providers/Microsoft.Network/virtualNetworks/uks-pprd-example-vnet"
  subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-example-vnet-rg/providers/Microsoft.Network/virtualNetworks/uks-pprd-example-vnet/subnets/aks01"
  private_dns_zone_id = "System"
  cluster = {
    "kubernetes_version" = "1.35"
    "subnet_key"         = "aks01"
    "pod_cidr"           = "172.20.0.0/16"
    "service_cidr"       = "172.22.0.0/20"
    "dns_service_ip"     = "172.22.0.10"
    "ingress_private_ip" = "10.81.0.20"
    "system_pool" = {
      "vm_size"    = "Standard_D4s_v5"
      "node_count" = 1
      "zones"      = ["1"]
    }
    "user_pools" = {
      "apps" = {
        "vm_size"    = "Standard_D4s_v5"
        "node_count" = 1
        "zones"      = ["1"]
      }
    }
  }
}
run "private_security" {
  command = plan
  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].only_critical_addons_enabled && azurerm_kubernetes_cluster.this.default_node_pool[0].host_encryption_enabled
    error_message = "Dedicated system scheduling and host encryption must remain enabled by default."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.this.private_cluster_enabled && !azurerm_kubernetes_cluster.this.private_cluster_public_fqdn_enabled && azurerm_kubernetes_cluster.this.local_account_disabled && !azurerm_kubernetes_cluster.this.run_command_enabled
    error_message = "Private Entra-only control-plane access must remain the default."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.network_profile[0].network_plugin_mode == "overlay" && azurerm_kubernetes_cluster.this.network_profile[0].network_data_plane == "cilium" && azurerm_kubernetes_cluster.this.network_profile[0].outbound_type == "loadBalancer"
    error_message = "Preserve CNI Overlay/Cilium with a functional managed-egress default."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.oidc_issuer_enabled && azurerm_kubernetes_cluster.this.workload_identity_enabled && azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled && azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_rotation_enabled
    error_message = "Preserve workload identity, Azure RBAC and secret rotation."
  }
}
run "fixed_pool_sizes" {
  command = plan
  variables {
    cluster = {
      "kubernetes_version" = "1.35"
      "subnet_key"         = "aks01"
      "pod_cidr"           = "172.20.0.0/16"
      "service_cidr"       = "172.22.0.0/20"
      "dns_service_ip"     = "172.22.0.10"
      "ingress_private_ip" = "10.81.0.20"
      "system_pool" = {
        "vm_size"    = "Standard_D4s_v5"
        "node_count" = 2
      }
      "user_pools" = {
        "apps" = {
          "vm_size"    = "Standard_D4s_v5"
          "node_count" = 4
        }
      }
    }
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].node_count == 2 && azurerm_kubernetes_cluster_node_pool.user["apps"].node_count == 4 && !azurerm_kubernetes_cluster_node_pool.user["apps"].auto_scaling_enabled
    error_message = "Fixed pool counts must remain operator-controlled."
  }
}
run "autoscaling" {
  command = plan
  variables {
    cluster = {
      "kubernetes_version" = "1.35"
      "subnet_key"         = "aks01"
      "pod_cidr"           = "172.20.0.0/16"
      "service_cidr"       = "172.22.0.0/20"
      "dns_service_ip"     = "172.22.0.10"
      "ingress_private_ip" = "10.81.0.20"
      "system_pool" = {
        "vm_size"    = "Standard_D4s_v5"
        "node_count" = 1
        "zones"      = ["1"]
        "min_count"  = 1
        "max_count"  = 3
      }
      "user_pools" = {
        "apps" = {
          "vm_size"    = "Standard_D4s_v5"
          "node_count" = 1
          "zones"      = ["1"]
          "min_count"  = 1
          "max_count"  = 3
        }
      }
    }
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].auto_scaling_enabled && azurerm_kubernetes_cluster.this.default_node_pool[0].min_count == 1 && azurerm_kubernetes_cluster_node_pool.user["apps"].max_count == 3
    error_message = "Independent pool autoscaler bounds must reach AKS."
  }
}
run "reject_unready_udr" {
  command = plan
  variables {
    cluster = {
      "kubernetes_version" = "1.35"
      "subnet_key"         = "aks01"
      "pod_cidr"           = "172.20.0.0/16"
      "service_cidr"       = "172.22.0.0/20"
      "dns_service_ip"     = "172.22.0.10"
      "ingress_private_ip" = "10.81.0.20"
      "system_pool" = {
        "vm_size"    = "Standard_D4s_v5"
        "node_count" = 1
        "zones"      = ["1"]
      }
      "user_pools" = {
        "apps" = {
          "vm_size"    = "Standard_D4s_v5"
          "node_count" = 1
          "zones"      = ["1"]
        }
      }
      "outbound_type" = "userDefinedRouting"
    }
  }

  expect_failures = [var.cluster]

}
run "ready_udr" {
  command = plan
  variables {
    cluster = {
      "kubernetes_version" = "1.35"
      "subnet_key"         = "aks01"
      "pod_cidr"           = "172.20.0.0/16"
      "service_cidr"       = "172.22.0.0/20"
      "dns_service_ip"     = "172.22.0.10"
      "ingress_private_ip" = "10.81.0.20"
      "system_pool" = {
        "vm_size"    = "Standard_D4s_v5"
        "node_count" = 1
        "zones"      = ["1"]
      }
      "user_pools" = {
        "apps" = {
          "vm_size"    = "Standard_D4s_v5"
          "node_count" = 1
          "zones"      = ["1"]
        }
      }
      "outbound_type"    = "userDefinedRouting"
      "udr_egress_ready" = true
      "route_table_id"   = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/egress-rg/providers/Microsoft.Network/routeTables/aks-egress"
    }
  }
  assert {
    condition     = azurerm_role_assignment.route_table[0].scope == var.cluster.route_table_id && azurerm_role_assignment.route_table[0].role_definition_name == "Network Contributor"
    error_message = "UDR requires control-plane access to the actual route table."
  }
}
run "custom_dns_and_registry" {
  command = apply
  variables {
    private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/uks-hub-example-dns-rg/providers/Microsoft.Network/privateDnsZones/privatelink.uksouth.azmk8s.io"
    acr_registries = {
      "images" = {
        "id"        = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/images-rg/providers/Microsoft.ContainerRegistry/registries/exampleimages"
        "pull_role" = "Container Registry Repository Reader"
      }
    }
  }
  assert {
    condition     = azurerm_role_assignment.private_dns[0].scope == var.private_dns_zone_id && azurerm_role_assignment.acr_pull["images"].role_definition_name == "Container Registry Repository Reader"
    error_message = "Custom DNS permissions and ABAC registry pull roles must be explicit."
  }
  assert {
    condition     = azurerm_role_assignment.acr_pull["images"].principal_id == azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
    error_message = "ACR pulls must use the kubelet object ID."
  }
}
run "monitoring" {
  command = plan
  variables {
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/monitor-rg/providers/Microsoft.OperationalInsights/workspaces/examplelogs"
  }
  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 1 && azurerm_monitor_diagnostic_setting.this[0].log_analytics_destination_type == "Dedicated" && azurerm_kubernetes_cluster.this.oms_agent[0].msi_auth_for_monitoring_enabled
    error_message = "An explicit workspace enables managed-identity monitoring and dedicated diagnostic tables."
  }
}

run "reject_unsupported_os" {
  command = plan
  variables {
    cluster = {
      kubernetes_version = "1.35"
      subnet_key         = "aks01"
      pod_cidr           = "172.20.0.0/16"
      service_cidr       = "172.22.0.0/20"
      dns_service_ip     = "172.22.0.10"
      os_sku             = "AzureLinux3"
      system_pool        = { vm_size = "Standard_D4s_v5" }
      user_pools         = { apps = { vm_size = "Standard_D4s_v5" } }
    }
  }
  expect_failures = [var.cluster]
}

run "native_authorization_keeps_entra_private_access" {
  command = plan
  variables {
    kubernetes_authorization_mode = "kubernetes_rbac"
    entra_admin_group_object_ids  = ["00000000-0000-0000-0000-000000000031"]
  }
  assert {
    condition = (!azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled &&
      toset(azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].admin_group_object_ids) == toset(["00000000-0000-0000-0000-000000000031"]) &&
      azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].tenant_id == var.tenant_id &&
      azurerm_kubernetes_cluster.this.local_account_disabled &&
      !azurerm_kubernetes_cluster.this.run_command_enabled &&
      azurerm_kubernetes_cluster.this.private_cluster_enabled &&
      azurerm_kubernetes_cluster.this.oidc_issuer_enabled &&
      azurerm_kubernetes_cluster.this.workload_identity_enabled &&
    length(azurerm_role_assignment.cluster_admin) == 0)
    error_message = "Native authorization changes the API authorizer only; Entra, private access, workload identity and local-account protections must remain."
  }
}


run "disposable_lab_shared_system_pool" {
  command = plan
  variables {
    cluster = {
      kubernetes_version = "1.35"
      subnet_key         = "aks01"
      pod_cidr           = "172.20.0.0/16"
      service_cidr       = "172.22.0.0/20"
      dns_service_ip     = "172.22.0.10"
      sku_tier           = "Free"
      system_pool = {
        vm_size                      = "Standard_D4s_v4"
        node_count                   = 2
        only_critical_addons_enabled = false
      }
      user_pools = {}
    }
  }
  assert {
    condition     = !azurerm_kubernetes_cluster.this.default_node_pool[0].only_critical_addons_enabled && azurerm_kubernetes_cluster.this.default_node_pool[0].node_count == 2 && length(azurerm_kubernetes_cluster_node_pool.user) == 0
    error_message = "Only the explicit disposable profile may share its two-node system pool without user pools."
  }
  assert {
    condition     = output.system_pool.vm_size == "Standard_D4s_v4" && output.system_pool.max_surge == "10%" && output.system_pool.host_encryption_enabled && output.sku_tier == "Free"
    error_message = "Expose the actual lab capacity and retain surge/encryption defaults."
  }
}
run "reject_dedicated_system_without_user_pool" {
  command = plan
  variables {
    cluster = {
      kubernetes_version = "1.35"
      subnet_key         = "aks01"
      pod_cidr           = "172.20.0.0/16"
      service_cidr       = "172.22.0.0/20"
      dns_service_ip     = "172.22.0.10"
      system_pool = {
        vm_size    = "Standard_D4s_v4"
        node_count = 2
      }
      user_pools = {}
    }
  }
  expect_failures = [var.cluster]
}
