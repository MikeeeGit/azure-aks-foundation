locals {
  delivery = jsondecode(file("${path.root}/delivery.azure.json"))
}
resource "terraform_data" "delivery_contract" {
  lifecycle {
    precondition {
      condition     = lower(var.tenant_id) == lower(local.delivery.tenant_id) && var.subscription_id_map == tomap(local.delivery.subscriptions)
      error_message = "Terraform tenant/subscription aliases must exactly match delivery.azure.json."
    }
    precondition {
      condition     = try(local.delivery.environments[var.environment].subscription_alias == var.subscription, false) && contains(local.delivery.regions, var.location_abbreviated)
      error_message = "The selected environment subscription alias and region must match delivery.azure.json."
    }
  }
}
