subscription         = "prd"
environment          = "prd"
location             = "uksouth"
location_abbreviated = "uks"
network = {
  "vnet_id"        = "/subscriptions/00000000-0000-0000-0000-000000000004/resourceGroups/uks-prd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-prd-vnet-01"
  "address_spaces" = ["10.82.0.0/16"]
  "subnet_ids" = {
    "aks01" = "/subscriptions/00000000-0000-0000-0000-000000000004/resourceGroups/uks-prd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-prd-vnet-01/subnets/uks-prd-aks01"
    "aks02" = "/subscriptions/00000000-0000-0000-0000-000000000004/resourceGroups/uks-prd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-prd-vnet-01/subnets/uks-prd-aks02"
  }
  "subnet_address_prefixes" = {
    "aks01" = "10.82.0.0/22"
    "aks02" = "10.82.4.0/22"
  }
}
connected_address_spaces = ["10.80.0.0/16", "10.81.0.0/16"]
clusters = {
  "aks01" = {
    "kubernetes_version" = "1.35"
    "subnet_key"         = "aks01"
    "pod_cidr"           = "172.20.0.0/16"
    "service_cidr"       = "172.22.0.0/20"
    "dns_service_ip"     = "172.22.0.10"
    "ingress_private_ip" = "10.82.0.20"
    "system_pool" = {
      "vm_size"    = "Standard_D4s_v5"
      "node_count" = 3
      "zones"      = ["1", "2", "3"]
      "min_count"  = 3
      "max_count"  = 6
    }
    "user_pools" = {
      "apps" = {
        "vm_size"    = "Standard_D4s_v5"
        "node_count" = 3
        "zones"      = ["1", "2", "3"]
        "min_count"  = 3
        "max_count"  = 6
      }
    }
  }
  "aks02" = {
    "kubernetes_version" = "1.36"
    "subnet_key"         = "aks02"
    "pod_cidr"           = "172.21.0.0/16"
    "service_cidr"       = "172.22.16.0/20"
    "dns_service_ip"     = "172.22.16.10"
    "ingress_private_ip" = "10.82.4.20"
    "system_pool" = {
      "vm_size"    = "Standard_D4s_v5"
      "node_count" = 3
      "zones"      = ["1", "2", "3"]
      "min_count"  = 3
      "max_count"  = 6
    }
    "user_pools" = {
      "apps" = {
        "vm_size"    = "Standard_D4s_v5"
        "node_count" = 3
        "zones"      = ["1", "2", "3"]
        "min_count"  = 3
        "max_count"  = 6
      }
    }
  }
}
private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/uks-hub-vnet-rg-01/providers/Microsoft.Network/privateDnsZones/privatelink.uksouth.azmk8s.io"

# Same reviewed hub ACR used by the sample build and both cluster kubelets.
acr_registries = {
  platform = {
    id        = "/subscriptions/00000000-0000-0000-0000-000000000002/resourceGroups/uks-hub-netw-rg-01/providers/Microsoft.ContainerRegistry/registries/exampleplatformacr"
    pull_role = "AcrPull"
  }
}
