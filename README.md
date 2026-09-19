# Azure AKS Foundation

Terraform for one or two private Azure Kubernetes Service clusters in an existing Azure network. Stable slots `aks01` and `aks02` support independent Kubernetes versions and node pools so applications can move between clusters during upgrades. This public version preserves the core design of the author's archived `AZ-TF-aks` configuration with synthetic configuration and explicit dependencies.

Each cluster uses Azure CNI Overlay with Cilium, Entra authentication and Azure RBAC, OIDC/workload identity, dedicated control-plane and kubelet identities, Linux system/user pools, Key Vault CSI secret rotation and optional Log Analytics diagnostics. Application permissions belong to separate workload identities. No kubeconfig or administrator credentials are exported.

The stack creates AKS resources, identities and scoped role assignments. An existing network, state backend, optional shared private DNS, ACR and monitoring workspace are inputs. Applications, ingress controllers, load balancer Services, Application Gateway, DNS traffic records and application cutover are separate operational layers. The `ingress_handoff` output describes requested ingress addresses; it does not claim those addresses exist.

Start with [getting started](docs/getting-started.md), then choose the [single-cluster](examples/single/README.md) or [dual hub-and-spoke](examples/dual-hub-spoke/README.md) scenario. Follow [blue/green operations](docs/blue-green.md) for cutover and rollback. [Configuration](docs/configuration.md) explains the input/output contract; [identity and ingress](docs/identity-and-ingress.md) covers application integration.

| Target | Example | Existing network | Slots |
|---|---|---|---|
| `uks/dev` | Smaller starting point | UK South spoke | `aks01` |
| `uks/pprd` | Dual cluster, shared hub DNS | `10.81.0.0/16` spoke | `aks01`, `aks02` |
| `uks/prd` | Dual cluster, three-zone pool examples | `10.82.0.0/16` spoke | `aks01`, `aks02` |
| `ukw/bcdr` | Separate recovery deployment/state | UK West spoke | `aks01` |

All IDs are synthetic. Kubernetes `1.35` and `1.36` are illustrative current minor versions, not a promise that every region, SKU or subscription can deploy them. Check regional availability, quota and supported patches before planning a deployment. UK West examples omit availability zones; verify regional capabilities independently.

Development is pinned to Terraform 1.16.3 and AzureRM 4.81.0. Configuration constraints allow Terraform >=1.9,<2 and AzureRM >=4.33,<5; the 4.33 minimum is also tested. Credential-free provider mocks prove configuration behavior, not live Azure deployment or application availability. See [testing](docs/testing.md).

Public CI uses isolated hosted workers without cloud authentication. Authenticated delivery belongs in a trusted private consumer using [Terraform Delivery Templates](https://github.com/MikeeeGit/terraform-delivery-templates), reviewed OIDC identities and environment approvals. Never attach Azure credentials or persistent trusted runners to public pull-request validation.

[Source review and changes](docs/source-provenance.md) records retained behavior and deliberate changes. This is a new deployment interface/state layout, not a drop-in migration of existing AVM state. Licensed under [Apache-2.0](LICENSE).

Review the [infrastructure-to-application readiness handoff](docs/readiness.md) before creating nodes, deploying applications or selecting the candidate slot.

Optional [ingress TLS profile](examples/ingress-tls/README.md) preserves workload identity, CSI certificate synchronization and gateway-to-controller HTTPS as an explicit path beside the simple direct-ILB demo.

## CI change scope

Markdown-only edits use lightweight required GitHub checks and are excluded from automatic Azure validation builds. Changes to Terraform, application code, scripts, workflow definitions or executable examples still run full validation, including examples stored under docs/. Mixed changes also run full validation. Manual GitHub runs and unknown Git comparison ranges default to full validation.
