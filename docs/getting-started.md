# From an existing network to private AKS

## Prepare private configuration and state

Clone/import the public source into a private deployment repository before adding real estate configuration or authenticated delivery. Use Terraform 1.16.3, Azure CLI, Python 3.10+, Git and a reviewed delivery-helper release. This root has a partial Azure AD backend; supply its actual account, container and key through `delivery.azure.json` and the helpers.

Starting from nothing, follow the delivery framework's [Azure bootstrap guide](https://github.com/MikeeeGit/terraform-delivery-templates/blob/v0.2.0/docs/azure/bootstrap.md): local-state bootstrap, migration to protected remote state and OIDC prerequisites. Choose globally unique storage names. AKS and network must have separate state keys. Backend readers can read full snapshots; restrict that access.

Edit `delivery.azure.json` and `config/global.tfvars` together. Tenant and subscription maps must match; Terraform checks this and the selected environment alias before cluster creation. Workload and backend subscription aliases can differ. The default state key is `<repository>-<environment>-<region>.tfstate`; retain it deliberately after the first deployment, including if the repository is renamed.

## Apply network and DNS prerequisites

Deploy [Azure Network Foundation](https://github.com/MikeeeGit/azure-network-foundation) first, or provide an equivalent network. The full UK South scenario has hub `10.80.0.0/16`, pre-production `10.81.0.0/16` and production `10.82.0.0/16`. Spoke node subnets are `aks01` (`.0.0/22`) and `aks02` (`.4.0/22`); the separate `appgateway` subnet uses `.8.0/24`. AKS node subnets must not be delegated to another service. Overlay pods use separate cluster CIDRs.

Copy the applied spoke's VNet ID/address spaces and subnet IDs/CIDRs into the target's `network` object. The sample IDs follow the network pack names, such as `uks-pprd-vnet-rg-01`, `uks-pprd-vnet-01` and `uks-pprd-aks01`. Alternatively set `network = null` and supply an explicit `network_remote_state` backend as described in [configuration](configuration.md).

For shared DNS, obtain the hub output `managed_private_dns_zone_ids["privatelink.uksouth.azmk8s.io"]` and set `private_dns_zone_id` to that actual resource ID. The network owner must create the zone and its spoke/management VNet links before AKS. This stack grants each cluster identity Private DNS Zone Contributor on the zone and Network Contributor on its VNet; it does not own shared zones/links. Register `Microsoft.ContainerService` in both subscriptions if custom DNS is in another subscription. See [private cluster requirements](https://learn.microsoft.com/en-us/azure/aks/private-clusters).

If a spoke uses a hub firewall/custom DNS resolver, an AKS-managed System zone in the spoke is not automatically visible to that resolver. Add the required hub link or conditional forwarding after creation, or use the prelinked shared custom hub zone from the full example. Verify DNS before node/bootstrap operations.

The single-cluster target uses `private_dns_zone_id = "System"` for AKS-managed DNS. Management clients still need routed private API access and working name resolution. Do not guess API IPs or commit hosts-file workarounds. Public FQDN publishing, local accounts and Run Command are disabled.

Populate `connected_address_spaces` with all hub, peer and on-premises CIDRs. Cluster pod/service ranges must not overlap these networks or each other. Terraform cannot discover omitted external networks. Budget pod space, subnet space and VM quota for both clusters and upgrade surge; overlay allocates a `/24` pod block per node. See [CNI Overlay planning](https://learn.microsoft.com/en-us/azure/aks/concepts-network-azure-cni-overlay).

## Select functional outbound access

Samples use `outbound_type = "loadBalancer"`. Private API access does not remove node outbound requirements; managed outbound can create public egress addresses. Review existing routes/NSGs/DNS against [AKS required outbound dependencies](https://learn.microsoft.com/en-us/azure/aks/outbound-rules-control-egress).

For UDR, first apply and verify firewall/NVA egress, its real next-hop IP and the route-table associations on both node subnets. Set each slot's `outbound_type = "userDefinedRouting"`, `route_table_id` to the actual table and `udr_egress_ready = true`. The cluster identity receives Network Contributor on that table. The flag acknowledges readiness; it does not probe networking. Never attach a default route to a nonexistent next hop. Review [UDR prerequisites](https://learn.microsoft.com/en-us/azure/aks/egress-udr) before changing an existing outbound mode.

## Configure capacity and permissions

Replace all synthetic IDs and review the complete layered target. Each `clusters` entry has an independent version and pools. Adding `aks02` creates a second cluster; removing its key schedules destruction. Later tfvars replace whole maps, so an override of `clusters` must contain every slot you intend to keep.

Use Entra groups in `cluster_admin_principal_ids`. The deployment identity needs resource-management and role-assignment rights at the actual AKS, VNet, DNS, route-table and optional application/registry scopes, including explicit scopes in another subscription. This stack uses one workload provider; role scopes are resource IDs in the same tenant. Register needed Azure providers first (`Microsoft.ContainerService`, `Microsoft.Network`, `Microsoft.ManagedIdentity` and monitoring providers if used). Automatic registration is disabled so plan readers do not need registration rights.

Optional `acr_registries` grants kubelet pull roles: `AcrPull` for classic RBAC or `Container Registry Repository Reader` for RBAC+ABAC mode. The module does not discover that mode. Optional `log_analytics_workspace_id` enables Container Insights and diagnostics; review costs and workspace retention. App Key Vault access belongs in `workload_identities`, with narrowly scoped roles. No vault or certificate-write grant is required merely to create a cluster.

## Validate, plan and apply

Credential-free verification:

```bash
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
terraform test
terraform test -test-directory=tests/targets -var-file=config/global.tfvars -var-file=config/uks/pprd/pprd.tfvars
```

Mocks cannot verify your real estate IDs. In your own authenticated environment, check tenant/subscription, regional versions, VM sizes, encryption-at-host support, zone support and quota:

```bash
az login --tenant YOUR_TENANT_ID
az account set --subscription YOUR_WORKLOAD_SUBSCRIPTION_ID
az aks get-versions --location uksouth --output table
az vm list-skus --location uksouth --resource-type virtualMachines --all --output table
```

Encryption-at-host defaults to enabled on every pool. Register the `Microsoft.Compute/EncryptionAtHost` feature in each workload subscription and wait for it to become registered before cluster creation, then refresh Microsoft.Compute provider registration as required by the [AKS host-encryption guide](https://learn.microsoft.com/en-us/azure/aks/enable-host-encryption). Verify that the selected VM size supports it; change the explicit per-pool option only after reviewing that security choice.

Choose supported patches using the [AKS release calendar](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions). Ubuntu is the sample OS; Azure Linux 2 images have retired. From the private checkout, source the reviewed helper release and select the target:

```bash
source ../terraform-delivery-templates/scripts/azure/terraform-functions.sh
tf_setup azure-aks-foundation pprd uks
tf_env
tf_init
tf_plan
# Review the saved plan, subscription, state key and resource changes.
tf_apply
```

The helper asks for confirmation and applies the saved plan. Input/context changes require a new plan. See its [Bash/PowerShell guide](https://github.com/MikeeeGit/terraform-delivery-templates/blob/v0.2.0/docs/azure/local-helpers.md). Private CI requires OIDC, trusted branches, private-consumer guards and protected apply environments; use the framework private starters. Keep public validation unauthenticated.

## Verify access and hand off applications

From a routed client that resolves the private API FQDN, obtain user credentials and use `kubelogin`:

```bash
az aks get-credentials --resource-group YOUR_AKS_RESOURCE_GROUP --name YOUR_CLUSTER_NAME
kubelogin convert-kubeconfig -l azurecli
kubectl get nodes
kubectl get pods --all-namespaces
```

Do not request administrator credentials. Verify Entra RBAC, node readiness, DNS/egress, registry pulls, CSI and workload identity independently on both clusters. Role/federation propagation can take time. Continue with [identity and ingress](identity-and-ingress.md) and the [cutover runbook](blue-green.md). No Azure deployment is performed by public mock tests.
