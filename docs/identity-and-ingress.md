# Workload identity and internal ingress

Each cluster has a dedicated control-plane identity and an explicit separate kubelet identity. The control plane gets Network Contributor on its VNet, Private DNS Zone Contributor on a supplied custom zone, Network Contributor on a selected UDR table, and Managed Identity Operator only on its kubelet identity. Registry pull roles target the kubelet. Application permissions are explicit `workload_identities`; no blanket app-vault/certificate access is attached to cluster identities.

Example private environment input:

```hcl
workload_identities = {
  web = {
    service_accounts = {
      web = {
        namespace       = "demo"
        service_account = "web"
        clusters        = ["aks01", "aks02"]
      }
    }
    role_assignments = {
      secrets = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/apps-rg/providers/Microsoft.KeyVault/vaults/example-app"
        role_definition_name = "Key Vault Secrets User"
      }
    }
  }
}
```

One application identity gets a credential per selected cluster issuer and exact `system:serviceaccount:<namespace>:<name>` subject. Azure permits at most 20 credentials per identity; issuer/subject pairs must be unique. Credential propagation can take time. See [federation restrictions](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation-considerations).

Annotate the ServiceAccount with `azure.workload.identity/client-id` using the application output client ID. Pods need label `azure.workload.identity/use: "true"` and that `serviceAccountName`. Key Vault CSI workload identity also requires a SecretProviderClass with `clientID`, `tenantId`, vault and object references. The AKS add-on alone does not create these resources or mount secrets. See [CSI identity setup](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-identity-access) and [sample metadata](../examples/kubernetes/workload-identity.yaml).

Install a maintained ingress implementation separately. Its Service uses `service.beta.kubernetes.io/azure-load-balancer-internal: "true"` and `service.beta.kubernetes.io/azure-load-balancer-ipv4` for a free address in the correct node subnet. A different internal subnet requires explicit configuration and identity permissions. Check NSGs, routes, probes and actual address allocation. See [internal load balancer guidance](https://learn.microsoft.com/en-us/azure/aks/internal-lb). [internal-service.yaml](../examples/kubernetes/internal-service.yaml) only illustrates the Service contract: adapt selectors/ports to a controller you have actually installed.

Gateway health must be proved after ingress exists. Overlay pods are not gateway backend targets. ACR and Key Vault private endpoints independently require functioning DNS/network access; RBAC grants do not create that connectivity.


## Integrated public sample

The [platform demo](https://github.com/MikeeeGit/aks-platform-demo) deploys a namespaced application and an internal LoadBalancer Service to each cluster through [shared Kustomize delivery](https://github.com/MikeeeGit/aks-delivery-templates). Its Services use the reserved ingress_handoff addresses and can be Application Gateway backends directly. This one-app path needs no ingress controller. A general multi-application platform still needs its own maintained controller design.

The full UK South configuration grants both kubelet identities pull access to the hub example ACR. Replace the synthetic registry ID with the applied hub acr_id and choose the pull role that matches its RBAC/ABAC mode. Application deploy identities need separate cluster-user and namespace-scoped permissions; they are not kubelet or workload identities.

Use the deployment_context and clusters outputs with the [platform handoff helper](https://github.com/MikeeeGit/terraform-delivery-templates/blob/v0.3.0/scripts/azure/platform_handoff.py) to create reviewed application targets from actual cluster names. That helper exports metadata only and does not grant permissions or deploy workloads.
