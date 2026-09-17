# Source review and deliberate public changes

Sources reviewed were the top-level `AZ-TF-aks/` and `AZ-TF-MOD-aks/` entries in the author's March 2026 repository archive. The archive remains unchanged. No original Git history, organization tfvars, credentials, kubeconfigs, application settings or private estate identifiers were copied.

The archived root actually calls `Azure/avm-res-containerservice-managedcluster/azurerm` 0.1.7 twice (`main.tf:521` and `:730`). Its README claims it uses the standalone `AZ-TF-MOD-aks`, but the root does not reference that module. The actual root uses CNI Overlay with Cilium; the standalone native module uses Calico (`main.tf:94`). This public root preserves the actual deployed-root Cilium configuration. A consumer of the old standalone Calico module must separately review network-policy compatibility and migration; this is not an implicit in-place conversion.

| Archived behavior | Public implementation |
|---|---|
| Optional second same-region cluster on `aks01`/`aks02` | One/two stable map slots; preserved independent resource/subnet lifecycle |
| Both clusters share version/pool variables | Independent per-slot versions and system/user pools |
| All inspected environment tfvars disable secondary | Honest single/dual examples; no claim that the archive proves an active dual deployment |
| Private API with regional private DNS | Retained; explicit existing custom zone/links or AKS-managed System zone |
| Hardcoded shared subscription/zone and reconstructed network IDs | Explicit subscription aliases, network outputs, backend and resource IDs |
| UDR selected without creating egress | Retained capability; managed outbound default, actual route-table input/readiness gate for UDR |
| Shared identity for both control planes and all workload federation | Separate control-plane/kubelet identities per slot plus explicit application identities |
| Entra RBAC, OIDC, workload federation, CSI, ACR and diagnostics | Retained with scoped roles, correct kubelet pull principals and optional workspace |
| Enabled local administrator accounts/Run Command | Disabled; routed private Entra user access documented |
| Zero-minute drain/soak | 30-minute drain, 5-minute soak, 10% surge |
| Standalone module ignores user-pool node_count changes | Fixed counts remain managed; explicit bounds enable autoscaling |
| Optional certificate-vault variable with unconditional lookup/wrong alias | No mandatory vault lookups; explicit app-role scopes support independent vaults/subscriptions |
| Raw sensitive kubeconfig outputs | Removed; state still requires protection because providers may retain sensitive computed data |
| Old versions and broad provider constraints | Tested lockfile, current illustrative versions and regional preflight |
| Private app/database troubleshooting, admin/hosts-file examples | Synthetic setup, DNS/Entra access and explicit app handoff/cutover guides |

The old standalone module's `acr_id` is unused; the archived root creates actual kubelet ACR roles separately. The public module implements those grants explicitly, including the ABAC registry role option. Optional application certificate write roles are not defaults; add a specifically reviewed role through `workload_identities` only when the application needs it.

Ubuntu is the supported node OS in this release. The archive left OS SKU unset. An explicit AzureLinux3 option is deferred until a reviewed provider-minimum update; AzureRM 4.33 does not accept that enum.

The self-contained native AzureRM child avoids the archived AVM dependency graph. AVM 0.1.7 required Terraform >=1.9.2 despite the archived root declaring >=1.8. Native resources change state addresses, identities and interfaces. **Do not point this configuration at archived AVM state or treat it as an in-place upgrade.** Existing deployments need a separately reviewed import/migration plan and full state backup, or a new candidate deployment followed by controlled application migration. No automated state migration is supplied.

Scope remains infrastructure configuration and delivery integration. It does not deploy apps/databases/ingress, perform gateway traffic changes, replicate recovery data or prove production readiness. Those require explicit operational work. Public mock tests do not establish live cloud or application outcomes.
