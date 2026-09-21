# Configuration and output contract

The root is a deployment stack; `modules/cluster` is its native single-cluster implementation. The root provider selects an explicit workload subscription/tenant. State storage is selected separately. `config/global.tfvars` loads before `config/<region>/<environment>/<environment>.tfvars`, matching Terraform Delivery Templates. Later variables replace whole maps rather than deep-merging them.

| Input | Meaning |
|---|---|
| `tenant_id`, `subscription_id_map`, `subscription` | Workload tenant/alias; checked against delivery configuration |
| `environment`, `location`, `location_abbreviated`, `company_abbreviation` | Names and target |
| `network` | Existing VNet ID/address spaces and node subnet IDs/CIDRs |
| `network_remote_state` | Alternative explicit AzureRM network-state backend; exactly one source |
| `connected_address_spaces` | Additional hub/peer/on-premises CIDRs for overlap checks |
| `private_dns_zone_id` | `System` or existing regional AKS private DNS resource ID |
| `clusters` | One/two independent stable slots (`aks01`, `aks02`) |
| `cluster_admin_principal_ids` | Explicit Azure RBAC cluster administrators; empty in native Kubernetes mode |
| `kubernetes_authorization_mode` | `azure_rbac` default or explicit `kubernetes_rbac` |
| `entra_admin_group_object_ids` | Native-mode Entra administrator groups for first bootstrap/recovery |
| `delivery_principals` | Applied CI client/object IDs, purpose, namespaces and selected slots; Cluster User grants only |
| `acr_registries` | Registry ID and the kubelet pull role matching its permission mode |
| `log_analytics_workspace_id` | Optional existing workspace for OMS and diagnostics |
| `workload_identities` | Dedicated app identities, Kubernetes subjects and Azure role scopes |

This release accepts Ubuntu OS to keep the AzureRM 4.33 compatibility contract honest. Explicit AzureLinux3 requires a newer provider API/validation contract and is not accepted here.

Each cluster needs a Kubernetes version, subnet key, pod/service CIDRs, DNS service IP, system pool and normally at least one user pool. Both `min_count`/`max_count` enable autoscaling; omit both for a fixed `node_count`. VM size, zones, max pods, disks, labels and taints are independent by pool. Fixed counts are not hidden by lifecycle ignores. The system pool admits critical add-ons by default; use user pools for applications. The explicit `system_pool.only_critical_addons_enabled = false` opt-in permits application scheduling on system nodes and allows an empty user-pool map for a [disposable lab](../examples/disposable-lab/README.md). Optional `autoscaler_profile` preserves the original cluster-level tuning. NodeImage upgrades stay enabled; Kubernetes versions are reviewed inputs. Upgrade defaults are 30-minute drain, 5-minute soak and 10% surge.

`outbound_type` accepts `loadBalancer` or `userDefinedRouting`. UDR also needs `route_table_id` and `udr_egress_ready`. An optional `ingress_private_ip` must be usable in that slot's node subnet; it is metadata, not an allocated address.

Example remote network backend (replace all synthetic values):

```hcl
network = null
network_remote_state = {
  subscription_id      = "00000000-0000-0000-0000-000000000002"
  resource_group_name  = "ukw-pprd-tfstate-rsg"
  storage_account_name = "ukwpprdexampletfstatesa"
  container_name       = "ukw-pprd-azdo-tfstate"
  key                  = "azure-network-foundation-pprd-uks.tfstate"
  use_azuread_auth      = true
}
```

The selected spoke state must expose `vnet_id`, `vnet.address_space`, `subnet_ids` and `subnet_address_prefixes`. Supply the hub custom DNS zone ID explicitly from `managed_private_dns_zone_ids`. Remote-state readers can read the whole snapshot, not only outputs; explicit inputs are preferable across trust boundaries. Network state must exist before AKS planning.

Outputs contain no kubeconfig:

- `clusters`: name, ID, RG, private FQDN, issuer URL, control-plane identity ID, kubelet IDs, node RG, subnet, requested version, actual system-pool settings, user-pool count and AKS tier per slot.
- `workload_identities`: per-app client/principal/resource IDs, tenant, service-account/federation bindings and applied Azure role-assignment scope/name metadata. These identifiers are not secrets.
- `delivery_authorization`: selected authorizer, applied CI principal scopes, administrator groups and Cluster User assignments; see [authorization](ci-identity-and-authorization.md).
- `ingress_handoff`: desired private IP/subnet with `created_by_this_stack = false`; consume only after ingress exists and is healthy.
- `resource_group_name`: stack-owned AKS/application-identity resource group.

Checks reject overlapping cluster ranges, declared network overlap, wrong node-subnet/VNet membership, invalid DNS/ingress addresses and duplicate slot subnets. They cannot discover omitted external ranges, occupied IPs, absent DNS links, live routes, firewall policies or Azure capacity. Verify these separately.

The active examples use at least two system nodes (three for production), a system autoscaler minimum of at least two, and illustrative D4 sizes. Confirm the current [system-pool requirements](https://learn.microsoft.com/en-us/azure/aks/use-system-pools), VM availability and quota before provisioning. The ordinary PPRD pair now starts six D4 nodes (four system and two application nodes): 24 vCPUs, rising to 36 at the declared autoscaler maxima, before surge and private workers. The explicit mixed-system lab profile starts 16 vCPUs instead.
