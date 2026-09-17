# Dual cluster in a hub-and-spoke network

Use `config/global.tfvars` followed by `config/uks/pprd/pprd.tfvars` (or the independent production target). Network keys are `aks01` and `aks02`. The network owner creates the regional AKS private DNS zone and links it to the spoke and management networks before this stack. The two slots have independent versions and pools; neither is automatically the active application target.

The example uses managed load-balancer outbound until a working egress firewall and routes have been verified. For each slot, set `outbound_type = "userDefinedRouting"`, `route_table_id` to the applied egress route table, and `udr_egress_ready = true` only after that verification. The helper grants each control-plane identity Network Contributor on that route table. This flag is an operator acknowledgement, not a connectivity test.

See [network-to-cluster setup](../../docs/getting-started.md) and [blue/green cutover](../../docs/blue-green.md). The desired ingress IPs are metadata only. An ingress controller and its internal load balancer must exist before a gateway can use those IPs.
