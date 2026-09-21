# Disposable dual-AKS lab capacity profile

This additive input demonstrates a smaller dual-cluster rehearsal using the real Azure foundation. It keeps two private clusters, managed Entra/native Kubernetes authorization, workload identities, CSI, Cilium and the two application slots. It has **not been validated by a live Azure deployment**.

Each slot has two `Standard_D4s_v4` system nodes, no separate user pool, fixed counts and the Free AKS tier. The deliberate `system_pool.only_critical_addons_enabled = false` lets the demo application and Envoy workloads share the system pool. Normal inputs default to `true`, retaining the dedicated system-pool taint and the requirement for a separate user pool.

This is a disposable nonproduction tradeoff. Application/controller resource pressure can now affect system workloads, and a two-node cluster has limited spare capacity during drains or failures. The Free tier has no financially backed API-server SLA. Do not copy this profile into production without a capacity and reliability review.

## Capacity and quota

Microsoft's current [system node-pool guidance](https://learn.microsoft.com/en-us/azure/aks/use-system-pools) requires at least two nodes and a VM size with at least four vCPUs and four GB memory; B-series sizes are unsupported for system pools. These inputs use four vCPUs and 16 GiB per node.

| Capacity event | AKS nodes | AKS vCPUs |
| --- | ---: | ---: |
| Both slots at steady state | 4 | 16 |
| One slot adds its upgrade surge node | 5 | 20 |
| Both slots surge concurrently | 6 | 24 |

The module keeps its existing `max_surge = "10%"`; on a two-node pool this rounds up to one additional node. A serial upgrade plan therefore needs **20 regional and DSv4-family vCPUs**, plus any private worker and other VMs. Concurrent upgrades need **24**, plus those other resources. Check quotas for both the region and VM family; visible SKU availability does not grant quota or guarantee allocation capacity. Do not submit this profile to a region with only 10 vCPUs available.

No autoscaler is enabled by this example. Terraform/node-image replacement, quota consumption elsewhere and platform resource requests can still affect available capacity. Reserve time and budget for retries and cleanup; stopping an application is not infrastructure teardown.

## Private consumer inputs

Layer [clusters.tfvars](clusters.tfvars) after a complete private environment input. Terraform replaces the entire `clusters` map, so reconcile all intended slot values rather than mixing partial maps accidentally.

```bash
terraform init -input=false -lockfile=readonly
terraform plan \
  -var-file=config/global.tfvars \
  -var-file=config/uks/pprd/pprd.tfvars \
  -var-file=examples/disposable-lab/clusters.tfvars \
  -out=private-lab.tfplan
```

The committed global/environment inputs are synthetic. Replace tenant/subscription/admin-group IDs, network and DNS resource IDs, versions, zones, registry and workload/CI identities in a private consumer before a real plan. Keep the plan private; review cost and resource ownership before apply. The example neither provisions a private worker nor creates an existing Entra group.

Host encryption remains explicitly `true`. Check subscription feature registration and selected SKU support before provisioning. If encryption at host is unavailable and a disposable trial consciously accepts that difference, set `host_encryption_enabled = false` only in its reviewed private input for each affected pool. The public defaults do not silently disable it.

Use the complete [three-tier Azure walkthrough](https://github.com/MikeeeGit/terraform-delivery-templates/blob/main/docs/azure/three-tier-worked-example.md) for network/identity/state prerequisites, platform bootstrap, application deployment, switchover and removal. The existing [native authorization example](../native-rbac/README.md) explains the CI/workload identity separation.

## Credential-free validation and cleanup

Both CI hosts test this layered profile with provider mocks. Checks assert two two-node system pools, explicit shared scheduling, zero user pools, Free tier, retained host encryption and the surge contract. These checks prove Terraform wiring; real allocation, Entra federation, private DNS, Key Vault CSI and application traffic still need live qualification.

For removal, follow the worked-example teardown while the private worker, identities and state backend remain available. Remove application/platform dependencies first, destroy only the inventoried lab Terraform states, and verify that worker/network/billable resources created for the trial are removed or explicitly retained. Keep shared infrastructure and Entra groups outside the teardown scope.
