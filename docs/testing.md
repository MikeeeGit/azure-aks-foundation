# Local and CI verification

Use Terraform 1.16.3 and committed provider lockfiles. Tests mock AzureRM and do not read the Azure backend. Root tests use synthetic network inputs and an overridden remote-state fixture. The child ACR test performs a mocked apply to verify computed kubelet identity propagation; no real resources are created.

```bash
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
terraform test
terraform -chdir=modules/cluster init -backend=false -input=false -lockfile=readonly
terraform -chdir=modules/cluster validate
terraform -chdir=modules/cluster test
for target in uks/dev uks/pprd uks/prd ukw/bcdr; do
  environment="${target#*/}"
  terraform test -test-directory=tests/targets -var-file=config/global.tfvars -var-file="config/$target/$environment.tfvars"
done
```

Tests cover private API/local accounts, Cilium, OIDC/CSI/RBAC, independent versions/subnets, fixed/autoscaled pools, route-table/DNS/registry roles, monitoring, federation, target-binding drift and invalid IP ranges. Additional access tests cover the unchanged Azure RBAC default, explicit native-mode administrator groups, private/Entra security preservation, distinct platform/app identities, selected-slot Cluster User grants, namespace restrictions and applied authorization metadata. AzureRM 4.81 and the declared minimum 4.33 are tested with the pinned CLI. Public GitHub/Azure Pipelines use isolated hosted workers and the shared validation entrypoint, including the child and each layered target.

Mocks prove Terraform evaluation and selected invariants. They do not prove regional Kubernetes/VM availability, API acceptance, role propagation, private DNS/routing, actual network policy, ACR/vault reachability or application health/cutover. A separately approved private deployment must verify these. AzureRM 4.81 warns that FIC `resource_group_name` is deprecated; it is retained for the 4.33 compatibility contract and can be removed with a deliberate future minimum-version change.

Keep default validation credential-free. Real plans/state and deployment jobs belong in private trusted consumers with reviewed OIDC, approval settings and secure artifacts. Do not provide cloud credentials or persistent trusted runners to public PR jobs.
