provider "azurerm" {
  features {}
  tenant_id                       = var.tenant_id
  subscription_id                 = var.subscription_id_map[var.subscription]
  resource_provider_registrations = "none"
}
