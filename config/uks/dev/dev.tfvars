# One private cluster, AKS-managed private DNS, managed load-balancer outbound.
subscription         = "pprd"
environment          = "dev"
location             = "uksouth"
location_abbreviated = "uks"
network = {
  "vnet_id"        = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01"
  "address_spaces" = ["10.81.0.0/16"]
  "subnet_ids" = {
    "aks01" = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01/subnets/uks-pprd-aks01"
    "aks02" = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-vnet-rg-01/providers/Microsoft.Network/virtualNetworks/uks-pprd-vnet-01/subnets/uks-pprd-aks02"
  }
  "subnet_address_prefixes" = {
    "aks01" = "10.81.0.0/22"
    "aks02" = "10.81.4.0/22"
  }
}
connected_address_spaces = []
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
