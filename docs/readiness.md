# Infrastructure-to-application readiness

This checklist describes evidence an operator collects in a private environment. It does not claim that the public examples have been deployed or that an archived environment is still running. Keep infrastructure, application release and traffic cutover as separately reviewed operations.

| Dependency | Required evidence before proceeding |
|---|---|
| Target and state | Actual tenant/subscriptions, selected environment/region, dedicated state keys and reviewed plans match the intended resources |
| Network | Both slot subnet IDs/prefixes exist; hub/spoke peering is connected; NSGs permit DNS, API, probes and intended application paths |
| DNS | Each slot can resolve the private AKS API and required service zones through its real resolver path; custom upstreams have no circular forwarding |
| Egress | For UDR, actual firewall policy and routes exist on both AKS subnets, required platform/registry endpoints work, and only then `udr_egress_ready=true`; loadBalancer mode has its own verified outbound path |
| Registry | Actual login/data endpoints are permitted and both kubelet identities have the pull role appropriate to registry RBAC/ABAC mode; an authenticated image pull succeeds from each slot |
| Private API | A trusted private operator/deployment worker resolves and reaches each cluster API and obtains Entra user access; no admin kubeconfig is required |
| Application identities | Each workload ServiceAccount has the intended client ID, each selected slot's OIDC issuer is federated, and the application has only its required resource roles |
| Vault/CSI | DNS/network reachability, SecretProviderClass object references, ServiceAccount/pod labels and actual secret/certificate retrieval succeed; the CSI add-on alone is insufficient |
| Backend services | Each internal LoadBalancer gets its reserved actual address, endpoints/probes are ready, and requests with the configured Host/path succeed from the gateway/diagnostic path |
| Gateway | Correct listener certificate/SANs, Key Vault access, backend health, WAF policies, Host/path/rewrite behavior and candidate-only test route are verified |
| Cutover | Candidate application/data compatibility, rollback target, exact image/infrastructure/traffic revisions and observation criteria are recorded |

The complete synthetic layout separates ownership: network foundation owns VNets/subnets/peerings/zones, azure-firewall owns the firewall and policy, the route add-on owns AKS routes, this root owns clusters and identities, delivery owns Kubernetes applications/Services, and Application Gateway owns listeners and its optional stable backend alias. Never create the same resource or association in two states.

Network/DNS and egress should be ready before node creation. Changing VNet DNS after clients exist needs a separately planned refresh of their effective settings; a Terraform update alone does not demonstrate propagation. During a dual-slot upgrade, verify the candidate first while retaining the serving slot and its identity/federation.

For the single-app sample, a direct internal LoadBalancer Service is sufficient; no ingress controller is implied. General ingress platforms need their own maintained controller, routes and probes. Desired `ingress_handoff` IPs are metadata until Kubernetes/Azure allocate and expose them. Do not route gateway traffic to overlay pod CIDRs or the private API endpoint.

Use [identity and ingress](identity-and-ingress.md), [dual-slot cutover](blue-green.md) and the [gateway cutover guide](https://github.com/MikeeeGit/azure-application-gateway/blob/main/docs/cutover.md). Stop at the failing dependency rather than bypassing it with broader roles, public API access or a guessed route address. Successful schema/mock checks do not replace these live checks.
