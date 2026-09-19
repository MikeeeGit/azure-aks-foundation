# Design and migration compatibility

This component creates one or two private AKS clusters using native AzureRM resources. Stable slots support independently selected Kubernetes versions, system/user node pools and application releases.

## Configuration design

- Azure CNI Overlay with Cilium; migrating from Calico requires a separate network-policy compatibility review.
- Private API access through explicitly configured DNS and a routed management path.
- Independent control-plane and kubelet identities per slot, with separate application workload identities.
- Explicit subscription, subnet, DNS, registry and role-scope inputs.
- Entra authorization, OIDC federation, CSI integration and optional diagnostics.
- Local administrator accounts and Run Command disabled.
- Explicit upgrade drain, soak and surge settings, plus fixed-count or autoscaling pool configuration.
- Kubelet ACR grants, including the optional ABAC registry role.
- No raw kubeconfig outputs; Terraform state still requires protection because providers may retain sensitive computed data.

Ubuntu is the supported node OS in this release. AzureLinux3 requires a reviewed provider-minimum update; AzureRM 4.33 does not accept that enum. Regional Kubernetes versions and VM availability must be checked before deployment.

## State and workload migration

Native AzureRM resources have different state addresses and interfaces from Azure Verified Modules. Do not point this configuration at existing AVM state or treat it as an automatic in-place upgrade. Existing infrastructure needs a reviewed inventory, import/state-migration plan and protected state backup, or a new candidate deployment followed by controlled workload migration. No automated state migration is supplied.

Review network policies, DNS, identity bindings, registry permissions and workload certificate access for each cluster independently. Optional certificate write roles are not defaults; add a reviewed role through workload identities only when the application requires it.

## Component boundaries

This repository owns cluster infrastructure and delivery metadata. It does not deploy applications, databases or ingress controllers, switch gateway traffic, or replicate recovery data. Use the [readiness guide](readiness.md) to verify private access, both cluster slots and application handoffs. Provider-mocked tests validate configuration contracts; live Azure acceptance is a separate deployment step.
