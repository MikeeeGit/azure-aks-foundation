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
  tenant_id = "00000000-0000-0000-0000-000000000001"
  subscription_id_map = {
    "hub"  = "00000000-0000-0000-0000-000000000002"
    "pprd" = "00000000-0000-0000-0000-000000000003"
    "prd"  = "00000000-0000-0000-0000-000000000004"
  }
  company_abbreviation = "example"
  global_tags = {
    "Project" = "Azure AKS Foundation"
    "Owner"   = "Platform Engineering"
  }
  subscription         = "pprd"
  environment          = "pprd"
  location             = "uksouth"
  location_abbreviated = "uks"
  network = {
    "vnet_id"        = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-example-vnet-rg/providers/Microsoft.Network/virtualNetworks/uks-pprd-example-vnet"
    "address_spaces" = ["10.81.0.0/16"]
    "subnet_ids" = {
      "aks01" = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-example-vnet-rg/providers/Microsoft.Network/virtualNetworks/uks-pprd-example-vnet/subnets/aks01"
      "aks02" = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-example-vnet-rg/providers/Microsoft.Network/virtualNetworks/uks-pprd-example-vnet/subnets/aks02"
    }
    "subnet_address_prefixes" = {
      "aks01" = "10.81.0.0/22"
      "aks02" = "10.81.4.0/22"
    }
  }
  connected_address_spaces = ["10.80.0.0/16", "10.82.0.0/16"]
  clusters = {
    "aks01" = {
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
    "aks02" = {
      "kubernetes_version" = "1.36"
      "subnet_key"         = "aks02"
      "pod_cidr"           = "172.21.0.0/16"
      "service_cidr"       = "172.22.16.0/20"
      "dns_service_ip"     = "172.22.16.10"
      "ingress_private_ip" = "10.81.4.20"
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
}
run "dual_clusters" {
  command = plan
  assert {
    condition     = length(output.clusters) == 2 && output.clusters["aks01"].kubernetes_version == "1.35" && output.clusters["aks02"].kubernetes_version == "1.36"
    error_message = "The two slots must retain independent Kubernetes versions."
  }
  assert {
    condition     = output.clusters["aks01"].subnet_id != output.clusters["aks02"].subnet_id && output.ingress_handoff["aks01"].private_ip == "10.81.0.20" && !output.ingress_handoff["aks01"].created_by_this_stack
    error_message = "Each slot needs its own subnet and honest ingress handoff metadata."
  }
}
run "single_cluster" {
  command = plan
  variables {
    clusters = {
      "aks01" = {
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
  }
  assert {
    condition     = length(output.clusters) == 1 && !contains(keys(output.clusters), "aks02")
    error_message = "The single-cluster example must not create the second slot."
  }
}
run "federates_both_clusters" {
  command = plan
  variables {
    workload_identities = {
      "app" = {
        "service_accounts" = {
          "web" = {
            "namespace"       = "demo"
            "service_account" = "web"
            "clusters"        = ["aks01", "aks02"]
          }
        }
        "role_assignments" = {
          "secrets" = {
            "scope"                = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/apps-rg/providers/Microsoft.KeyVault/vaults/example-app"
            "role_definition_name" = "Key Vault Secrets User"
          }
        }
      }
    }
  }
  assert {
    condition     = length(azurerm_federated_identity_credential.workload) == 2 && alltrue([for f in azurerm_federated_identity_credential.workload : f.subject == "system:serviceaccount:demo:web"])
    error_message = "The same application service account must federate independently with each issuer."
  }
  assert {
    condition     = length(azurerm_user_assigned_identity.workload) == 1 && azurerm_role_assignment.workload["app/secrets"].role_definition_name == "Key Vault Secrets User"
    error_message = "Application permissions must be explicit and separate from the control plane."
  }
}
run "overlapping_pods" {
  command = plan
  variables {
    clusters = {
      "aks01" = {
        "kubernetes_version" = "1.35"
        "subnet_key"         = "aks01"
        "pod_cidr"           = "172.21.0.0/16"
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
      "aks02" = {
        "kubernetes_version" = "1.36"
        "subnet_key"         = "aks02"
        "pod_cidr"           = "172.21.0.0/16"
        "service_cidr"       = "172.22.16.0/20"
        "dns_service_ip"     = "172.22.16.10"
        "ingress_private_ip" = "10.81.4.20"
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
  }

  expect_failures = [terraform_data.network_contract]

}
run "network_overlap" {
  command = plan
  variables {
    clusters = {
      "aks01" = {
        "kubernetes_version" = "1.35"
        "subnet_key"         = "aks01"
        "pod_cidr"           = "172.20.0.0/16"
        "service_cidr"       = "10.80.0.0/20"
        "dns_service_ip"     = "10.80.0.10"
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
      "aks02" = {
        "kubernetes_version" = "1.36"
        "subnet_key"         = "aks02"
        "pod_cidr"           = "172.21.0.0/16"
        "service_cidr"       = "172.22.16.0/20"
        "dns_service_ip"     = "172.22.16.10"
        "ingress_private_ip" = "10.81.4.20"
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
  }

  expect_failures = [terraform_data.network_contract]

}
run "invalid_dns" {
  command = plan
  variables {
    clusters = {
      "aks01" = {
        "kubernetes_version" = "1.35"
        "subnet_key"         = "aks01"
        "pod_cidr"           = "172.20.0.0/16"
        "service_cidr"       = "172.22.0.0/20"
        "dns_service_ip"     = "192.168.1.10"
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
      "aks02" = {
        "kubernetes_version" = "1.36"
        "subnet_key"         = "aks02"
        "pod_cidr"           = "172.21.0.0/16"
        "service_cidr"       = "172.22.16.0/20"
        "dns_service_ip"     = "172.22.16.10"
        "ingress_private_ip" = "10.81.4.20"
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
  }

  expect_failures = [terraform_data.network_contract]

}
run "invalid_ingress" {
  command = plan
  variables {
    clusters = {
      "aks01" = {
        "kubernetes_version" = "1.35"
        "subnet_key"         = "aks01"
        "pod_cidr"           = "172.20.0.0/16"
        "service_cidr"       = "172.22.0.0/20"
        "dns_service_ip"     = "172.22.0.10"
        "ingress_private_ip" = "10.81.9.20"
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
      "aks02" = {
        "kubernetes_version" = "1.36"
        "subnet_key"         = "aks02"
        "pod_cidr"           = "172.21.0.0/16"
        "service_cidr"       = "172.22.16.0/20"
        "dns_service_ip"     = "172.22.16.10"
        "ingress_private_ip" = "10.81.4.20"
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
  }

  expect_failures = [terraform_data.network_contract]

}

run "reject_target_tenant_drift" {
  command = plan
  variables { tenant_id = "00000000-0000-0000-0000-000000000099" }
  expect_failures = [terraform_data.delivery_contract]
}
run "reject_environment_alias_drift" {
  command = plan
  variables { subscription = "prd" }
  expect_failures = [terraform_data.delivery_contract]
}

run "remote_network_contract" {
  command = plan
  variables {
    network = null
    network_remote_state = {
      subscription_id      = "00000000-0000-0000-0000-000000000002"
      resource_group_name  = "ukw-pprd-tfstate-rsg"
      storage_account_name = "ukwpprdexampletfstatesa"
      container_name       = "ukw-pprd-azdo-tfstate"
      key                  = "azure-network-foundation-pprd-uks.tfstate"
    }
  }
  override_data {
    target = data.terraform_remote_state.network[0]
    values = {
      outputs = {
        vnet_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01"
        vnet    = { address_space = ["10.81.0.0/16"] }
        subnet_ids = {
          aks01 = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01/subnets/uks-pprd-aks01"
          aks02 = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01/subnets/uks-pprd-aks02"
        }
        subnet_address_prefixes = { aks01 = "10.81.0.0/22", aks02 = "10.81.4.0/22" }
      }
    }
  }
  assert {
    condition     = endswith(output.clusters["aks02"].subnet_id, "/uks-pprd-aks02")
    error_message = "Explicit remote network state must supply the correct independent slot subnet."
  }
}
run "reject_subscription_map_drift" {
  command = plan
  variables {
    subscription_id_map = {
      hub  = "00000000-0000-0000-0000-000000000002"
      pprd = "00000000-0000-0000-0000-000000000099"
      prd  = "00000000-0000-0000-0000-000000000004"
    }
  }
  expect_failures = [terraform_data.delivery_contract]
}
