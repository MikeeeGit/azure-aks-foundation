# Native Kubernetes authorization for the Azure reference

This additive profile uses managed Microsoft Entra authentication with native Kubernetes RBAC. Terraform still creates the real Azure clusters, workload federation and Azure permissions. The AKS root's existing Azure RBAC default is unchanged.

Merge [authorization.tfvars.example](authorization.tfvars.example) into the private PPRD or PRD target after replacing the synthetic IDs. Keep the complete cluster map and workload identity definitions. Terraform's later variable files replace entire maps; do not accidentally drop an existing application identity or slot.

Use separate applied platform and application CI identity outputs for each environment. The application identity is a deployment principal; it is separate from the workload identity annotated on Pods' ServiceAccount.

Follow [CI identity and authorization](../../docs/ci-identity-and-authorization.md) for first-bootstrap access, ownership and qualification. Creating Cluster User grants permits credential retrieval only; it does not make the platform or application pipeline authorized to change Kubernetes resources. The platform's permissions must be established separately before invoking its install pipeline.

This profile should first be used for a fresh private deployment. Changing the authorizer on an existing cluster changes which permission source controls access; inventory and stage replacement bindings using the approved administrator before making that change.
