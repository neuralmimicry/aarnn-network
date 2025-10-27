############################################
# Azure ACR module – creates a container registry and outputs login server
############################################

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

# Resource group (optional create)
resource "azurerm_resource_group" "rg" {
  name     = coalesce(var.resource_group, "${var.project_name}-rg")
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = replace("${var.project_name}${random_string.suffix.result}", "/[^a-z0-9]/", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

output "login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "ACR registry login server"
}
