# Separate regional deployment/state, requiring its own applied network.
subscription         = "prd"
environment          = "bcdr"
location             = "ukwest"
location_abbreviated = "ukw"
network = {
  "vnet_id"        = "/subscriptions/00000000-0000-0000-0000-000000000004/resourceGroups/ukw-bcdr-example-vnet-rg/providers/Microsoft.Network/virtualNetworks/ukw-bcdr-example-vnet"
  "address_spaces" = ["10.91.0.0/16"]
  "subnet_ids" = {
    "aks01" = "/subscriptions/00000000-0000-0000-0000-000000000004/resourceGroups/ukw-bcdr-example-vnet-rg/providers/Microsoft.Network/virtualNetworks/ukw-bcdr-example-vnet/subnets/aks01"
    "aks02" = "/subscriptions/00000000-0000-0000-0000-000000000004/resourceGroups/ukw-bcdr-example-vnet-rg/providers/Microsoft.Network/virtualNetworks/ukw-bcdr-example-vnet/subnets/aks02"
  }
  "subnet_address_prefixes" = {
    "aks01" = "10.91.0.0/22"
    "aks02" = "10.91.4.0/22"
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
    "ingress_private_ip" = "10.91.0.20"
    "system_pool" = {
      "vm_size"    = "Standard_D4s_v5"
      "node_count" = 1
      "zones"      = []
    }
    "user_pools" = {
      "apps" = {
        "vm_size"    = "Standard_D4s_v5"
        "node_count" = 1
        "zones"      = []
      }
    }
  }
}
