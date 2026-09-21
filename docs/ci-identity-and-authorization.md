# CI identity and Kubernetes authorization

The three deployment tiers use different identities with explicit owners. Terraform creates the infrastructure, application workload identities, AKS federation and Azure role assignments. The platform tier manages Kubernetes namespaces, controller configuration and application authorization. Application delivery authenticates as its own CI identity and deploys only the approved namespace resources.

## Identity and permission ownership

| Identity | Authentication | Permission owner |
|---|---|---|
| Terraform plan/apply CI | Git-host OIDC federation to a dedicated environment identity | Private bootstrap configuration owns backend, infrastructure and role-management scopes |
| Platform CI | Git-host OIDC federation to a separate platform identity | This stack owns Cluster User credential retrieval; separately provisioned Kubernetes authorization permits platform installation |
| Application CI | Git-host OIDC federation to a separate application identity | This stack owns Cluster User credential retrieval; platform-managed namespace bindings or the selected Azure RBAC model authorize application resources |
| Application workload | Exact Kubernetes ServiceAccount and each slot's AKS OIDC issuer | `workload_identities` owns UAMI, federated credentials and scoped Key Vault/other Azure roles |
| AKS control plane and kubelet | Dedicated user-assigned managed identities | Cluster module owns network/DNS/route and kubelet registry roles |

CI federation and workload federation are separate trust relationships. A Pod's identity must not acquire CI deployment privileges, and a deployment principal does not need the application's Key Vault role merely to install its ServiceAccount and SecretProviderClass. A trusted application deployer can still run code as the workload ServiceAccount; treat the application namespace as a trust boundary.

Use the framework's [Azure bootstrap](https://github.com/MikeeeGit/terraform-delivery-templates/blob/main/docs/azure/bootstrap.md) for backend provisioning, [stateful delivery identities](https://github.com/MikeeeGit/terraform-delivery-templates/tree/main/initial-setup/azure/delivery-identities) for per-environment UAMIs and GitHub federation, and [Azure DevOps connections](https://github.com/MikeeeGit/terraform-delivery-templates/tree/main/initial-setup/azure/azure-devops-connections) for service-issued federation and individual pipeline authorization. Pass the resulting non-secret client/object IDs into `delivery_principals`. The map supports distinct identities per environment, both slots or a selected slot, and explicit application namespaces. It rejects sharing the same identity between platform and application purposes. Terraform creates one **Azure Kubernetes Service Cluster User Role** assignment for every declared principal/slot pair. It creates no new Kubernetes administrator grants for these CI identities.

Removing a principal or slot from this map produces a role-assignment removal in the next reviewed Terraform plan. Kubernetes bindings have separate ownership and must also be reconciled. Existing manually created equivalent assignments require an explicit import/ownership transfer before Terraform manages them; do not let two mechanisms manage the same assignment.

## Select the API authorization model

`kubernetes_authorization_mode = "azure_rbac"` preserves the existing default. The existing `cluster_admin_principal_ids` input still grants Azure Kubernetes Service RBAC Cluster Admin explicitly. Application custom-resource permissions require their separately reviewed Azure authorization configuration; adding a CI principal here grants no Writer, custom-resource or administrator access. The [custom-resource authorization recipe](https://github.com/MikeeeGit/aks-delivery-templates/tree/main/examples/authorization) remains an optional profile. Microsoft's [custom-resource ABAC documentation](https://learn.microsoft.com/en-us/azure/aks/entra-id-authorization#restrict-custom-resource-access-using-abac-conditions-preview) identifies its group/kind filtering as preview.

`kubernetes_authorization_mode = "kubernetes_rbac"` retains managed Entra authentication and uses native Kubernetes Roles and RoleBindings for Kubernetes API authorization. This provides an explicit alternative for fine-grained Gateway API and CSI permissions. Configure a nonempty `entra_admin_group_object_ids` set of reviewed Entra security groups for initial bootstrap and recovery. Clear `cluster_admin_principal_ids`: Azure Kubernetes data roles are not the permission source in this mode. [Microsoft's native RBAC setup](https://learn.microsoft.com/en-us/azure/aks/azure-ad-rbac) describes this managed Entra configuration with Azure RBAC disabled.

The declared administrator groups have Kubernetes administrator rights and receive Cluster User credential retrieval access on both selected clusters. They are an explicit bootstrap/recovery input, not an automatically created identity. Group membership remains managed by its directory owner. The new CI principals receive credential retrieval only. A platform CI pipeline still needs its reviewed Kubernetes installation permissions established separately; neither a purpose label nor successful Azure login grants those permissions.

Both modes keep private APIs, disabled local accounts and disabled Run Command. Never use `az aks get-credentials --admin` as an authorization workaround. See the [native profile](../examples/native-rbac/README.md).

## Applied handoff and first bootstrap

Export selected non-sensitive outputs after applying the reviewed infrastructure plan. `delivery_authorization` includes the mode, administrator group IDs, exact CI client/object IDs, purpose, namespaces, selected slots, cluster IDs and Terraform-managed Cluster User assignments. Retain this together with `deployment_context`, `clusters` and `workload_identities` in the private consumer. The handoff contains no token or kubeconfig.

For native mode, an authorized Entra administrator connects through the private management path using user credentials. The platform tier's authorization code applies the intended application Role and RoleBinding declarations to each cluster. Platform installation permission is a separate reviewed prerequisite; it must exist before the platform CI job can install controllers or reconcile those bindings.

Determine the Kubernetes username under each actual CI login with `kubectl auth whoami`. Record that observation against the expected Azure client/object IDs; do not assume the Kubernetes username is either UUID. The [shared bootstrap guide](https://github.com/MikeeeGit/aks-delivery-templates/blob/main/docs/bootstrap.md) owns the namespace authorization procedure. Keep role bindings and expected principal mappings in private configuration so recreating either cluster does not rely on a remembered portal action.

Workload identity outputs remain independent. Each application UAMI has one exact federation per selected cluster issuer and ServiceAccount subject. Its output also records the applied role-assignment IDs, principals, scopes and role names so qualification can compare intended access with Azure. Feed its client ID, tenant, namespace and account into the platform/app ServiceAccount and CSI declarations using the [workload handoff](https://github.com/MikeeeGit/terraform-delivery-templates/blob/main/docs/azure/workload-identity-handoff.md). The example Key Vault scope must be replaced with a real owned vault; federation and roles do not create vault objects or network connectivity.

## Qualification

For each real Azure slot, verify private DNS/API connectivity, CI identity and kubeconfig retrieval, intended namespace writes, HTTPRoute/SecretProviderClass admission, Gateway reads, rejection of platform writes, workload CSI mounts and Key Vault access. Test the application with its actual deployment identity, not the bootstrap administrator. Reapply the declared permission configuration and verify removal of a test principal from both Azure and Kubernetes permission owners.

Provider-mocked tests verify default compatibility, native-mode safeguards, separate identities, slot/namespace selection and Terraform grant/output contracts. They cannot verify Entra claims, role propagation or actual Azure authorization. Record those results separately during the Azure rehearsal.
