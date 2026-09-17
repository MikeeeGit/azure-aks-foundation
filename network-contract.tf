locals {
  # IPv4 integer intervals permit overlap checks without cloud API calls.
  cidrs = concat(
    [for c in var.clusters : c.pod_cidr],
    [for c in var.clusters : c.service_cidr],
    local.network.address_spaces, tolist(var.connected_address_spaces)
  )
  ranges = { for cidr in distinct(local.cidrs) : cidr => {
    start = try(sum([for index, octet in split(".", cidrhost(cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]), -1)
    end   = try(sum([for index, octet in split(".", cidrhost(cidr, -1)) : tonumber(octet) * pow(256, 3 - index)]), -1)
  } }
  cluster_ranges = flatten([for key, c in var.clusters : [
    { key = "${key}/pods", cidr = c.pod_cidr },
    { key = "${key}/services", cidr = c.service_cidr }
  ]])
  network_ranges = concat(local.network.address_spaces, tolist(var.connected_address_spaces))
  subnet_ranges = { for key, cidr in local.network.subnet_address_prefixes : key => {
    start = try(sum([for index, octet in split(".", cidrhost(cidr, 0)) : tonumber(octet) * pow(256, 3 - index)]), -1)
    end   = try(sum([for index, octet in split(".", cidrhost(cidr, -1)) : tonumber(octet) * pow(256, 3 - index)]), -1)
  } }
  dns_ips     = { for key, c in var.clusters : key => try(sum([for index, octet in split(".", c.dns_service_ip) : tonumber(octet) * pow(256, 3 - index)]), -1) }
  ingress_ips = { for key, c in var.clusters : key => try(sum([for index, octet in split(".", c.ingress_private_ip) : tonumber(octet) * pow(256, 3 - index)]), -1) }
}
resource "terraform_data" "network_contract" {
  lifecycle {
    precondition {
      condition     = alltrue([for c in var.clusters : try(startswith(lower(local.network.subnet_ids[c.subnet_key]), "${lower(local.network.vnet_id)}/subnets/"), false)])
      error_message = "Every selected subnet ID must belong to the declared VNet."
    }
    precondition {
      condition     = alltrue([for c in var.clusters : try(anytrue([for vnet in local.network.address_spaces : local.subnet_ranges[c.subnet_key].start >= local.ranges[vnet].start && local.subnet_ranges[c.subnet_key].end <= local.ranges[vnet].end]), false)])
      error_message = "Every selected node subnet CIDR must be contained within the declared VNet address spaces."
    }
    precondition {
      condition     = (var.network == null) != (var.network_remote_state == null)
      error_message = "Provide exactly one explicit network or network_remote_state source."
    }
    precondition {
      condition     = length(local.network.address_spaces) > 0 && alltrue([for c in var.clusters : contains(keys(local.network.subnet_ids), c.subnet_key) && contains(keys(local.network.subnet_address_prefixes), c.subnet_key)])
      error_message = "The network must expose VNet CIDRs and the ID and CIDR of every cluster node subnet."
    }
    precondition {
      condition     = alltrue([for cidr in concat(local.cidrs, values(local.network.subnet_address_prefixes)) : can(cidrnetmask(cidr))])
      error_message = "This configuration requires valid IPv4 CIDRs."
    }
    precondition {
      condition     = alltrue(flatten([for a in local.cluster_ranges : [for b in local.cluster_ranges : a.key == b.key || local.ranges[a.cidr].end < local.ranges[b.cidr].start || local.ranges[b.cidr].end < local.ranges[a.cidr].start]])) && alltrue(flatten([for a in local.cluster_ranges : [for b in local.network_ranges : local.ranges[a.cidr].end < local.ranges[b].start || local.ranges[b].end < local.ranges[a.cidr].start]]))
      error_message = "Cluster pod/service CIDRs must be mutually disjoint and must not overlap VNet, peer or on-premises ranges."
    }
    precondition {
      condition     = alltrue([for key, c in var.clusters : can(cidrnetmask("${c.dns_service_ip}/32")) && local.dns_ips[key] > local.ranges[c.service_cidr].start + 1 && local.dns_ips[key] < local.ranges[c.service_cidr].end])
      error_message = "Each DNS service IP must be inside its service CIDR, excluding reserved first addresses and broadcast."
    }
    precondition {
      condition     = alltrue([for key, c in var.clusters : c.ingress_private_ip == null ? true : can(cidrnetmask("${c.ingress_private_ip}/32")) && try(local.ingress_ips[key] > local.subnet_ranges[c.subnet_key].start + 3 && local.ingress_ips[key] < local.subnet_ranges[c.subnet_key].end, false)])
      error_message = "A declared ingress IP must be usable within that cluster's node subnet. This does not allocate the IP."
    }
  }
}
