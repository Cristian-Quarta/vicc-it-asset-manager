terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

  skip_provider_registration = true
}

resource "azurerm_resource_group" "vicc" {
  name     = "rg-vicc-assetmanager"
  location = "Switzerland North"

  tags = {
    project     = "VICC Praxisarbeit"
    environment = "dev"
    managed_by  = "Terraform"
  }
}

resource "azurerm_container_registry" "vicc" {
  name                = "acrviccassetmanager"
  resource_group_name = azurerm_resource_group.vicc.name
  location            = azurerm_resource_group.vicc.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = {
    project     = "VICC Praxisarbeit"
    environment = "dev"
    managed_by  = "Terraform"
  }
}
