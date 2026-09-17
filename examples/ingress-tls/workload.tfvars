# Additional input after config/global.tfvars and the selected environment tfvars.
# Existing RBAC-enabled application Key Vault. Replace this synthetic ID before planning.
workload_identities = {
  platform-demo = {
    service_accounts = {
      app = {
        namespace       = "platform-demo"
        service_account = "platform-demo"
        clusters        = ["aks01", "aks02"]
      }
    }
    role_assignments = {
      tls-secret = {
        scope                = "/subscriptions/00000000-0000-0000-0000-000000000003/resourceGroups/uks-pprd-applications-rg/providers/Microsoft.KeyVault/vaults/example-platform-app"
        role_definition_name = "Key Vault Secrets User"
      }
    }
  }
}
