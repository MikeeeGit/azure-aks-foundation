variable "name" {
  type = string
}
variable "resource_group_name" {
  type = string
}
variable "location" {
  type = string
}
variable "tenant_id" {
  type = string
}
variable "vnet_id" {
  type = string
}
variable "subnet_id" {
  type = string
}
variable "private_dns_zone_id" {
  type = string
}
variable "log_analytics_workspace_id" {
  type    = string
  default = null
}
variable "cluster_admin_principal_ids" {
  type    = map(string)
  default = {}
}
variable "acr_registries" {
  type = map(object({ id = string, pull_role = string
  }))
  default = {}
}
variable "tags" {
  type    = map(string)
  default = {}
}
variable "cluster" {
  type = object({
    kubernetes_version = string
    subnet_key         = string
    pod_cidr           = string
    service_cidr       = string
    dns_service_ip     = string
    outbound_type      = optional(string, "loadBalancer")
    udr_egress_ready   = optional(bool, false)
    route_table_id     = optional(string)
    ingress_private_ip = optional(string)
    sku_tier           = optional(string, "Standard")
    os_sku             = optional(string, "Ubuntu")
    system_pool = object({
      vm_size                 = string
      node_count              = optional(number, 3)
      min_count               = optional(number)
      max_count               = optional(number)
      max_pods                = optional(number, 30)
      os_disk_size_gb         = optional(number, 128)
      zones                   = optional(set(string), ["1", "2", "3"])
      host_encryption_enabled = optional(bool, true)
    })
    user_pools = map(object({
      vm_size                 = string
      node_count              = optional(number, 3)
      min_count               = optional(number)
      max_count               = optional(number)
      max_pods                = optional(number, 100)
      os_disk_size_gb         = optional(number, 128)
      zones                   = optional(set(string), ["1", "2", "3"])
      host_encryption_enabled = optional(bool, true)
      node_labels             = optional(map(string), {})
      node_taints             = optional(list(string), [])
    }))
    autoscaler_profile = optional(object({
      balance_similar_node_groups      = optional(bool, true)
      expander                         = optional(string, "least-waste")
      max_graceful_termination_sec     = optional(string, "600")
      max_node_provisioning_time       = optional(string, "15m")
      max_unready_nodes                = optional(number, 3)
      max_unready_percentage           = optional(number, 45)
      scale_down_delay_after_add       = optional(string, "10m")
      scale_down_unneeded              = optional(string, "10m")
      scan_interval                    = optional(string, "10s")
      skip_nodes_with_local_storage    = optional(bool, true)
      skip_nodes_with_system_pods      = optional(bool, true)
      scale_down_utilization_threshold = optional(string, "0.5")
    }), {})
  })
  validation {
    condition     = can(regex("^1\\.[0-9]+(\\.[0-9]+)?$", var.cluster.kubernetes_version))
    error_message = "Use an explicit AKS Kubernetes minor or patch version, checked against the target region."
  }
  validation {
    condition     = contains(["loadBalancer", "userDefinedRouting"], var.cluster.outbound_type) && (var.cluster.outbound_type != "userDefinedRouting" || (var.cluster.udr_egress_ready && var.cluster.route_table_id != null))
    error_message = "UDR requires a route_table_id and udr_egress_ready=true after a working route, firewall/NVA, DNS and required outbound access are verified."
  }
  validation {
    condition     = var.cluster.os_sku == "Ubuntu" && contains(["Free", "Standard"], var.cluster.sku_tier)
    error_message = "This release supports Ubuntu OS and Free/Standard AKS tiers across the declared provider range."
  }
  validation {
    condition     = length(var.cluster.user_pools) > 0 && alltrue([for key in keys(var.cluster.user_pools) : can(regex("^[a-z][a-z0-9]{0,10}$", key)) && key != "systemnp"])
    error_message = "Provide at least one user pool with a distinct lowercase alphanumeric name of 1-11 characters."
  }
  validation {
    condition = alltrue([for pool in concat([var.cluster.system_pool], values(var.cluster.user_pools)) :
      pool.node_count >= 1 && floor(pool.node_count) == pool.node_count && pool.max_pods >= 10 && pool.max_pods <= 250 &&
      ((pool.min_count == null && pool.max_count == null) || try(pool.min_count >= 1 && pool.max_count >= pool.min_count && floor(pool.min_count) == pool.min_count && floor(pool.max_count) == pool.max_count, false))
    ])
    error_message = "Pool sizes must be positive integers. Configure both min/max to enable autoscaling; max_pods must be 10-250."
  }
}
