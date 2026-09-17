# Workload identity and CSI ingress TLS

This optional profile supplies the infrastructure and certificate contract shared by the maintained Gateway API path and the historical ingress compatibility path. The simple direct-ILB demo remains separate. It adds one application managed identity, exact ServiceAccount federation for both selected cluster issuers, and Key Vault Secrets User on an existing application vault. It does not create a vault, certificate, gateway/controller or Kubernetes object.

Apply the reviewed `workload.tfvars` after the root global and PPRD configuration. The map replaces `workload_identities`; merge any existing application identities explicitly before planning. For a single-cluster installation remove the unused slot from `clusters`. Replace the synthetic vault ID with your actual RBAC-enabled vault. The same dedicated application identity can serve both clusters; control-plane, kubelet, delivery and platform-service identities remain separate.

```bash
terraform test -test-directory=tests/ingress-tls \
  -var-file=config/global.tfvars -var-file=config/uks/pprd/pprd.tfvars \
  -var-file=examples/ingress-tls/workload.tfvars
```

This command runs from the repository root with a mocked provider. For real changes use your private configuration and the reviewed saved-plan infrastructure workflow.

## Bind the applied identity

After an approved infrastructure apply, export `terraform output -json` to a private ignored handoff file. Do not copy state. The [handoff helper](https://github.com/MikeeeGit/terraform-delivery-templates/blob/main/docs/azure/workload-identity-handoff.md) accepts `--workload-identity platform-demo --service-account-key app --workload-output workload.private.json` alongside its normal cluster/registry arguments. It checks the applied identity, exact namespace/ServiceAccount, issuer, audience and coverage of every selected slot. Review the generated ServiceAccount manifest and use its client/tenant IDs in the matching SecretProviderClass. It neither authenticates nor applies Kubernetes resources.

The namespace and ServiceAccount are `platform-demo`; the TLS Secret and SecretProviderClass are `platform-demo-tls`. Keep these exact references aligned across Terraform, ServiceAccount, pod, certificate sync, Gateway/Ingress and the application's route. A Gateway API `certificateRef` to a Secret in the same namespace avoids an unnecessary cross-namespace trust grant.

## Certificate synchronization

[secret-provider-class.yaml](secret-provider-class.yaml) is a complete TLS Secret synchronization definition. Replace the marked client/tenant values from the applied binding and the synthetic vault/certificate name. `objectType: secret` retrieves the private key and certificate; `cert` retrieves only public certificate material and cannot supply a TLS key. The certificate must have an exportable private key and a valid chain covering the actual backend Host/SNI names. Do not place certificate bytes or private keys in Git, tfvars or pipeline artifacts. See [Microsoft CSI identity and certificate behavior](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-identity-access) and [TLS Secret synchronization](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-nginx-tls).

A running pod must mount the CSI volume for synchronization to occur. [deployment-patch.yaml](deployment-patch.yaml) shows the workload identity label, ServiceAccount and read-only volume mount for the sample's `app` container. It is a patch, not a standalone Deployment. The complete application overlays live in [aks-platform-demo](https://github.com/MikeeeGit/aks-platform-demo). Retain a healthy mounting workload: the CSI-managed Secret lifecycle follows its consumers. AKS Foundation enables rotation polling, but prove certificate renewal and controller reload behavior in the chosen environment.

## Prerequisite gates

Before application delivery, the platform owner must establish the namespace and separately scoped custom-resource authorization needed to manage SecretProviderClasses. Built-in AKS RBAC Writer alone does not prove CSI CRD permissions. Verify `kubectl auth can-i create secretproviderclasses.secrets-store.csi.x-k8s.io -n platform-demo` as the actual deploy identity; stop if denied. Use the explicit user kubeconfig for the selected slot.

Both slots need a running Key Vault CSI add-on, OIDC/workload identity, effective vault secret-read permission, and node/provider access to the vault and identity endpoints through the reviewed firewall/DNS path. Application NetworkPolicy is not a replacement for node/provider egress. The synthetic app only serves HTTP, so it needs no blanket Internet egress.

Check the ServiceAccount binding, `SecretProviderClassPodStatus`, pod mount readiness, TLS Secret type/key names without printing key bytes, and actual certificate expiry/SAN/chain from a TLS client. Then verify the controller's allocated private frontend and HTTPS application responses from the gateway network. Port-forward application checks cannot establish these facts.

## Controller and traffic ownership

The maintained path uses a platform-owned Gateway API implementation. Historical ingress-nginx compatibility remains an explicit migration reference; the identity and certificate contract is identical. Do not let two Services own the same ILB address. During migration use a separately reserved candidate IP, or review an explicit ownership transfer after the old Service is removed.

Only after TLS and candidate health are proven should the [gateway HTTPS profile](https://github.com/MikeeeGit/azure-application-gateway/blob/main/examples/ingress-tls/README.md) be planned. Keep traffic cutover as a separate stable-DNS-record change and retain the old endpoint for rollback.
