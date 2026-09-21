variable "tenant_id" {
  type        = string
  description = "Microsoft Entra tenant. Must match delivery.azure.json."
}
variable "subscription_id_map" {
  type        = map(string)
  description = "Subscription aliases; same values as delivery.azure.json."
}
variable "subscription" {
  type        = string
  description = "Workload subscription alias. Backend subscription is configured independently."
  validation {
    condition     = contains(keys(var.subscription_id_map), var.subscription)
    error_message = "The selected subscription alias must exist in subscription_id_map."
  }
}
variable "environment" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,11}$", var.environment))
    error_message = "Use a lowercase environment identifier of 2-12 characters."
  }
}
variable "location" {
  type = string
}
variable "location_abbreviated" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,5}$", var.location_abbreviated))
    error_message = "Use a lowercase region identifier of 2-6 characters."
  }
}
variable "company_abbreviation" {
  type    = string
  default = "example"
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,15}$", var.company_abbreviation))
    error_message = "Use a lowercase name prefix of 2-16 characters."
  }
}
variable "global_tags" {
  type    = map(string)
  default = {}
}
variable "environment_tags" {
  type    = map(string)
  default = {}
}
variable "network" {
  description = "Explicit existing network outputs. Set exactly one of network and network_remote_state."
  type = object({
    vnet_id                 = string
    address_spaces          = list(string)
    subnet_ids              = map(string)
    subnet_address_prefixes = map(string)
  })
  default = null
}
variable "network_remote_state" {
  description = "Explicit Azure network state backend. State readers can read the entire state; prefer explicit network inputs across trust boundaries."
  type = object({
    subscription_id      = string
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
    use_azuread_auth     = optional(bool, true)
  })
  default = null
  validation {
    condition     = var.network_remote_state == null ? true : var.network_remote_state.use_azuread_auth
    error_message = "Remote state must use Microsoft Entra authentication."
  }
}
variable "connected_address_spaces" {
  type        = set(string)
  default     = []
  description = "All additional peered, hub and on-premises CIDRs; pod/service ranges must not overlap these."
}
variable "private_dns_zone_id" {
  type        = string
  default     = "System"
  description = "System for AKS-managed private DNS, or an existing regional privatelink.<region>.azmk8s.io zone ID. The network owner manages shared VNet links."
  validation {
    condition     = var.private_dns_zone_id == "System" || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft.Network/privateDnsZones/([^.]+\\.)?privatelink\\.[a-z0-9]+\\.azmk8s\\.io$", var.private_dns_zone_id))
    error_message = "Use System or an Azure AKS private DNS zone resource ID."
  }
}
variable "log_analytics_workspace_id" {
  type    = string
  default = null
}
variable "cluster_admin_principal_ids" {
  type        = map(string)
  default     = {}
  description = "Stable friendly keys to Entra object IDs granted cluster-scoped AKS RBAC Cluster Admin. Prefer groups."
}
variable "acr_registries" {
  type = map(object({
    id        = string
    pull_role = optional(string, "AcrPull")
  }))
  default     = {}
  description = "Registry IDs and kubelet pull role. ABAC-enabled registries require Container Registry Repository Reader."
  validation {
    condition     = alltrue([for v in var.acr_registries : contains(["AcrPull", "Container Registry Repository Reader"], v.pull_role)])
    error_message = "Use the pull role matching the registry permission mode."
  }
}
variable "clusters" {
  type = map(object({
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
  }))
  description = "One or two independent AKS slots. Removing a slot destroys that cluster after plan approval."
  validation {
    condition     = length(var.clusters) >= 1 && length(var.clusters) <= 2 && alltrue([for k in keys(var.clusters) : contains(["aks01", "aks02"], k)])
    error_message = "Configure one or two stable slots named aks01 and/or aks02."
  }
  validation {
    condition     = length(distinct([for c in var.clusters : c.subnet_key])) == length(var.clusters)
    error_message = "Each cluster must use a separate node subnet."
  }
}
variable "workload_identities" {
  description = "Separate application identities, explicit Kubernetes subjects and narrowly scoped Azure roles. No workload grants are created by default."
  type = map(object({
    service_accounts = map(object({
      namespace       = string
      service_account = string
      clusters        = set(string)
    }))
    role_assignments = optional(map(object({
      scope                = string
      role_definition_name = string
    })), {})
  }))
  default = {}
  validation {
    condition     = alltrue([for key, identity in var.workload_identities : can(regex("^[a-z][a-z0-9-]{0,23}$", key)) && alltrue([for sa in identity.service_accounts : can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", sa.namespace)) && can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", sa.service_account))])])
    error_message = "Use workload keys of 1-24 lowercase characters; service account and namespace names must be DNS labels of at most 63 characters."
  }
  validation {
    condition     = alltrue([for identity in var.workload_identities : length(distinct(flatten([for sa in identity.service_accounts : [for cluster in sa.clusters : "${cluster}/${sa.namespace}/${sa.service_account}"]]))) == sum(concat([0], [for sa in identity.service_accounts : length(sa.clusters)]))])
    error_message = "Each identity must have unique cluster/namespace/service-account federation subjects."
  }
  validation {
    condition     = alltrue(flatten([for identity in var.workload_identities : [for sa in identity.service_accounts : length(sa.clusters) > 0 && alltrue([for k in sa.clusters : contains(keys(var.clusters), k)])]]))
    error_message = "Workload federation must reference enabled cluster slots."
  }
  validation {
    condition     = alltrue([for identity in var.workload_identities : sum(concat([0], [for sa in identity.service_accounts : length(sa.clusters)])) <= 20])
    error_message = "An identity supports at most 20 federated identity credentials."
  }
}

variable "kubernetes_authorization_mode" {
  description = "Azure RBAC remains the default. kubernetes_rbac uses managed Entra authentication and platform-owned native Kubernetes bindings."
  type        = string
  default     = "azure_rbac"
  validation {
    condition     = (contains(["azure_rbac", "kubernetes_rbac"], var.kubernetes_authorization_mode))
    error_message = "Choose azure_rbac or kubernetes_rbac explicitly."
  }
  validation {
    condition     = (var.kubernetes_authorization_mode != "kubernetes_rbac" || length(var.cluster_admin_principal_ids) == 0)
    error_message = "Native Kubernetes authorization must use entra_admin_group_object_ids and managed Kubernetes bindings; remove Azure RBAC cluster_admin_principal_ids."
  }
}
variable "entra_admin_group_object_ids" {
  description = "Explicit Entra security group object IDs for first native-RBAC bootstrap and recovery. Required only for kubernetes_rbac; these groups have cluster administrator rights."
  type        = set(string)
  default     = []
  validation {
    condition     = (alltrue([for id in var.entra_admin_group_object_ids : can(regex("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$", id))]))
    error_message = "Provide Entra group object UUIDs."
  }
  validation {
    condition     = (var.kubernetes_authorization_mode == "kubernetes_rbac" ? length(var.entra_admin_group_object_ids) > 0 : length(var.entra_admin_group_object_ids) == 0)
    error_message = "Native Kubernetes authorization requires an explicit admin group; Azure RBAC uses cluster_admin_principal_ids instead."
  }
}

variable "delivery_principals" {
  description = "Applied CI identity outputs, separate from workload identities. Terraform owns Cluster User grants only. Kubernetes API permissions are separately provisioned through the selected authorization model."
  type = map(object({
    client_id    = string
    principal_id = string
    purpose      = string
    namespaces   = optional(set(string), [])
    clusters     = set(string)
  }))
  default = {}
  validation {
    condition = (alltrue([for key, identity in var.delivery_principals :
      can(regex("^[a-z][a-z0-9-]{0,39}$", key)) &&
      can(regex("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$", identity.client_id)) &&
      can(regex("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$", identity.principal_id)) &&
      lower(identity.client_id) != lower(identity.principal_id) &&
      contains(["platform", "application"], identity.purpose)
    ]))
    error_message = "Use stable delivery keys, distinct client/principal UUIDs and purpose platform or application."
  }
  validation {
    condition = (length(distinct([for identity in var.delivery_principals : lower(identity.client_id)])) == length(var.delivery_principals) &&
    length(distinct([for identity in var.delivery_principals : lower(identity.principal_id)])) == length(var.delivery_principals))
    error_message = "Each delivery principal must have a distinct client and object ID; platform and application identities must not be shared."
  }
  validation {
    condition = (alltrue([for identity in var.delivery_principals :
      length(identity.clusters) > 0 &&
      alltrue([for slot in identity.clusters : contains(keys(var.clusters), slot)]) &&
      (identity.purpose == "application" ? length(identity.namespaces) > 0 : length(identity.namespaces) == 0) &&
      alltrue([for namespace in identity.namespaces : can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", namespace)) && !contains(["default", "kube-system", "kube-public", "kube-node-lease", "envoy-gateway-system", "argocd"], namespace)])
    ]))
    error_message = "Select enabled cluster slots. Application identities require explicit application namespaces; platform principals are cluster-scoped. Reserved platform namespaces are not application targets."
  }
}
