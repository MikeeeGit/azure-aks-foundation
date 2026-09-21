# Disposable dual-AKS lab only. Merge after the complete environment/network input.
# All IDs are synthetic. Review real SKU availability, quota, cost and retention.
kubernetes_authorization_mode = "kubernetes_rbac"
entra_admin_group_object_ids  = ["00000000-0000-0000-0000-000000000031"]
cluster_admin_principal_ids   = {}

clusters = {
  aks01 = {
    kubernetes_version = "1.35"
    subnet_key         = "aks01"
    pod_cidr           = "172.20.0.0/16"
    service_cidr       = "172.22.0.0/20"
    dns_service_ip     = "172.22.0.10"
    ingress_private_ip = "10.81.0.20"
    sku_tier           = "Free"
    system_pool = {
      vm_size                      = "Standard_D4s_v4"
      node_count                   = 2
      max_pods                     = 30
      zones                        = ["1"]
      host_encryption_enabled      = true
      only_critical_addons_enabled = false
    }
    user_pools = {}
  }
  aks02 = {
    kubernetes_version = "1.35"
    subnet_key         = "aks02"
    pod_cidr           = "172.21.0.0/16"
    service_cidr       = "172.22.16.0/20"
    dns_service_ip     = "172.22.16.10"
    ingress_private_ip = "10.81.4.20"
    sku_tier           = "Free"
    system_pool = {
      vm_size                      = "Standard_D4s_v4"
      node_count                   = 2
      max_pods                     = 30
      zones                        = ["1"]
      host_encryption_enabled      = true
      only_critical_addons_enabled = false
    }
    user_pools = {}
  }
}
