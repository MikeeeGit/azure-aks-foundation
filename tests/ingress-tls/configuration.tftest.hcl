mock_provider "azurerm" {
  override_during = plan
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/mock-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mock"
      principal_id = "00000000-0000-0000-0000-000000000005"
      client_id    = "00000000-0000-0000-0000-000000000006"
    }
  }
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = {
      id                  = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/mock-rg/providers/Microsoft.ContainerService/managedClusters/mock"
      oidc_issuer_url     = "https://uksouth.oic.prod-aks.azure.com/example/issuer/"
      private_fqdn        = "mock.privatelink.uksouth.azmk8s.io"
      node_resource_group = "mock-nodes-rg"
      kubelet_identity    = [{ client_id = "00000000-0000-0000-0000-000000000007", object_id = "00000000-0000-0000-0000-000000000008", user_assigned_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/mock-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/kubelet" }]
    }
  }
}
run "workload_tls_federation" {
  command = plan
  assert {
    condition = length(output.workload_identities["platform-demo"].federated_credentials) == 2 && alltrue([
      for credential in values(output.workload_identities["platform-demo"].federated_credentials) :
      credential.subject == "system:serviceaccount:platform-demo:platform-demo" && credential.audience == tolist(["api://AzureADTokenExchange"])
    ])
    error_message = "TLS workload handoff must expose actual federation for both exact namespace/service-account subjects."
  }
  assert {
    condition     = azurerm_role_assignment.workload["platform-demo/tls-secret"].role_definition_name == "Key Vault Secrets User" && endswith(azurerm_role_assignment.workload["platform-demo/tls-secret"].scope, "/vaults/example-platform-app")
    error_message = "TLS workload access must target the existing application vault, separate from control-plane roles."
  }
  assert {
    condition     = length(output.workload_identities["platform-demo"].role_assignments) == 1 && output.workload_identities["platform-demo"].role_assignments["platform-demo/tls-secret"].role_definition_name == "Key Vault Secrets User" && endswith(output.workload_identities["platform-demo"].role_assignments["platform-demo/tls-secret"].scope, "/vaults/example-platform-app")
    error_message = "The applied workload handoff must expose exact role/scope metadata for Azure qualification."
  }
}
