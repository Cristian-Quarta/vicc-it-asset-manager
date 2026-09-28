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

resource "azurerm_postgresql_flexible_server" "vicc" {
  name                = "psql-vicc-assetmanager"
  resource_group_name = azurerm_resource_group.vicc.name
  location            = azurerm_resource_group.vicc.location
  version             = "16"
  zone                = "2"

  administrator_login    = "assetmanager"
  administrator_password = var.postgres_admin_password

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = {
    project     = "VICC Praxisarbeit"
    environment = "dev"
    managed_by  = "Terraform"
  }
}

resource "azurerm_postgresql_flexible_server_database" "assetdb" {
  name      = "assetdb"
  server_id = azurerm_postgresql_flexible_server.vicc.id

  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.vicc.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_container_app_environment" "vicc" {
  name                = "cae-vicc-assetmanager"
  location            = azurerm_resource_group.vicc.location
  resource_group_name = azurerm_resource_group.vicc.name

  tags = {
    project     = "VICC Praxisarbeit"
    environment = "dev"
    managed_by  = "Terraform"
  }
}

resource "azurerm_container_app" "vicc" {
  name                         = "ca-vicc-assetmanager"
  container_app_environment_id = azurerm_container_app_environment.vicc.id
  resource_group_name          = azurerm_resource_group.vicc.name
  revision_mode                = "Single"

  secret {
    name  = "database-url"
    value = "postgresql+psycopg://assetmanager:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.vicc.fqdn}:5432/assetdb"
  }

  secret {
    name  = "registry-password"
    value = azurerm_container_registry.vicc.admin_password
  }

  registry {
    server               = azurerm_container_registry.vicc.login_server
    username             = azurerm_container_registry.vicc.admin_username
    password_secret_name = "registry-password"
  }

  template {
    min_replicas = 1
    max_replicas = 2

    container {
      name   = "vicc-asset-manager"
      image  = "${azurerm_container_registry.vicc.login_server}/vicc-asset-manager:v1"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 5000

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = {
    project     = "VICC Praxisarbeit"
    environment = "dev"
    managed_by  = "Terraform"
  }
}
