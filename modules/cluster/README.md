# Native private AKS cluster

Internal child of the root `clusters` map. It creates a private Linux cluster, independent system/user pools, dedicated control-plane/kubelet identities, scoped network/DNS/route-table/registry/admin roles and optional monitoring. Outputs contain only non-secret metadata. Root-managed application federation allows one dedicated application identity to explicitly trust both cluster issuers.

See [variables.tf](variables.tf) for the typed contract and the [root setup guide](../../docs/getting-started.md) for dependencies. The root additionally checks address/VNet relationships; a direct child consumer must perform equivalent network validation. The child is versioned with this repository rather than independently published to a module registry.

Run `terraform init -backend=false`, `terraform validate` and `terraform test` here for mocked verification. The child lockfile supports reproducible validation.
