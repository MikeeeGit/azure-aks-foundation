# Changelog

## Unreleased

- Added an explicit controller-independent ingress TLS profile and focused offline integration checks.

- Reconcile September source (AKS Terraform unchanged); document network/DNS/egress/registry/identity/ILB readiness and clarify direct-Service versus controller-based ingress.

- Public Azure AKS foundation derived from reviewed archived root/native module.
- One/two independent private AKS slots with CNI Overlay and Cilium.
- Explicit network, DNS, backend, egress and workload identity contracts.
- Separate control-plane/kubelet/application identities; Entra-only access; no kubeconfig exports.
- Synthetic single/dual/production/recovery targets, mocked tests and network-to-cutover guides.

This is a new state/interface layout. It does not perform an in-place migration of archived AVM or Calico deployments.

The integrated sample also includes shared hub ACR pull grants and an explicit deployment_context metadata output for application target export.
