# =============================================================================
# VICC IT Asset Manager - Azure Infrastructure
# =============================================================================
# Diese Terraform-Konfiguration stellt die benötigte Azure-Infrastruktur
# für den IT Asset Manager bereit.
#
# Bereitgestellt werden:
# - Azure Resource Group
# - Azure Container Registry (ACR)
# - Azure Database for PostgreSQL Flexible Server
# - PostgreSQL-Datenbank
# - Firewall-Regel für Azure-Dienste
# - Azure Container Apps Environment
# - Azure Container App
#
# Die Infrastruktur wird vollständig als Infrastructure as Code (IaC)
# beschrieben und kann dadurch reproduzierbar bereitgestellt werden.
# =============================================================================


# -----------------------------------------------------------------------------
# Terraform und Provider
# -----------------------------------------------------------------------------

terraform {
  # Für dieses Projekt wird mindestens Terraform Version 1.6 benötigt.
  required_version = ">= 1.6.0"

  # AzureRM ist der Terraform-Provider für die Verwaltung
  # von Microsoft-Azure-Ressourcen.
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}


# Konfiguration des AzureRM-Providers.
provider "azurerm" {
  features {}

  # Die automatische Registrierung von Azure Resource Providern
  # wird deaktiviert. Benötigte Provider werden bei Bedarf separat
  # innerhalb der Azure Subscription registriert.
  skip_provider_registration = true
}


# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

# Die Resource Group dient als logischer Container für sämtliche
# Azure-Ressourcen des VICC IT Asset Managers.
resource "azurerm_resource_group" "vicc" {
  name     = "rg-vicc-assetmanager"
  location = "Switzerland North"

  # Einheitliche Tags erleichtern die Zuordnung und Verwaltung
  # der bereitgestellten Azure-Ressourcen.
  tags = {
    project     = "VICC Praxisarbeit"
    environment = "dev"
    managed_by  = "Terraform"
  }
}


# -----------------------------------------------------------------------------
# Azure Container Registry
# -----------------------------------------------------------------------------

# Die Azure Container Registry (ACR) speichert das Docker-Image
# der Flask-Anwendung.
#
# Azure Container Apps lädt das benötigte Image später direkt
# aus dieser Registry.
resource "azurerm_container_registry" "vicc" {
  name                = "acrviccassetmanager"
  resource_group_name = azurerm_resource_group.vicc.name
  location            = azurerm_resource_group.vicc.location

  # Für die Anforderungen der Entwicklungsumgebung reicht
  # die kostengünstige Basic-Variante aus.
  sku = "Basic"

  # Aktiviert die administrativen Zugangsdaten der Registry.
  # Diese werden von der Container App verwendet, um das
  # private Container-Image aus der Registry abzurufen.
  admin_enabled = true

  tags = {
    project     = "VICC Praxisarbeit"
    environment = "dev"
    managed_by  = "Terraform"
  }
}


# -----------------------------------------------------------------------------
# Azure Database for PostgreSQL
# -----------------------------------------------------------------------------

# Erstellt einen Azure Database for PostgreSQL Flexible Server.
# Die Datenbank wird als vollständig verwalteter Azure-Dienst (DBaaS)
# betrieben und ist damit vom Container der Anwendung getrennt.
resource "azurerm_postgresql_flexible_server" "vicc" {
  name                = "psql-vicc-assetmanager"
  resource_group_name = azurerm_resource_group.vicc.name
  location            = azurerm_resource_group.vicc.location

  # Verwendete PostgreSQL-Version und Availability Zone.
  version = "16"
  zone    = "2"

  # Der Administratorname wird direkt definiert.
  # Das Passwort befindet sich hingegen nicht im Quellcode,
  # sondern wird über eine sensitive Terraform-Variable übergeben.
  administrator_login    = "assetmanager"
  administrator_password = var.postgres_admin_password

  # Für die Entwicklungs- und Testumgebung wird eine kleine,
  # kostengünstige Serverkonfiguration verwendet.
  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  # Backups werden sieben Tage aufbewahrt.
  # Geo-redundante Backups werden für diese Entwicklungsumgebung
  # nicht benötigt.
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = {
    project     = "VICC Praxisarbeit"
    environment = "dev"
    managed_by  = "Terraform"
  }
}


# Erstellt innerhalb des PostgreSQL Flexible Servers die eigentliche
# Anwendungsdatenbank "assetdb".
resource "azurerm_postgresql_flexible_server_database" "assetdb" {
  name      = "assetdb"
  server_id = azurerm_postgresql_flexible_server.vicc.id

  charset   = "UTF8"
  collation = "en_US.utf8"
}


# -----------------------------------------------------------------------------
# PostgreSQL Firewall
# -----------------------------------------------------------------------------

# Erlaubt Azure-Diensten den Zugriff auf den PostgreSQL Flexible Server.
#
# Die spezielle Azure-Regel mit 0.0.0.0 ermöglicht der Container App,
# die Datenbank über die von Azure bereitgestellte Verbindung zu erreichen.
#
# Für eine produktive Umgebung wäre eine restriktivere Netzwerkanbindung,
# beispielsweise über private Netzwerke, zu bevorzugen.
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.vicc.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}


# -----------------------------------------------------------------------------
# Azure Container Apps Environment
# -----------------------------------------------------------------------------

# Das Container Apps Environment bildet die gemeinsame Azure-Laufzeitumgebung,
# innerhalb der die eigentliche Container App betrieben wird.
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


# -----------------------------------------------------------------------------
# Azure Container App
# -----------------------------------------------------------------------------

# Die Container App betreibt das Docker-Image der Flask-Webanwendung.
# Sie verbindet die Anwendung mit der Container Registry sowie mit
# Azure Database for PostgreSQL.
resource "azurerm_container_app" "vicc" {
  name                         = "ca-vicc-assetmanager"
  container_app_environment_id = azurerm_container_app_environment.vicc.id
  resource_group_name          = azurerm_resource_group.vicc.name

  # Es wird jeweils eine aktive Revision der Anwendung verwendet.
  revision_mode = "Single"


  # ---------------------------------------------------------------------------
  # Secrets
  # ---------------------------------------------------------------------------

  # Erstellt die PostgreSQL-Verbindungszeichenfolge.
  #
  # Das Datenbankpasswort stammt aus einer sensitiven Terraform-Variable
  # und wird nicht direkt im Quellcode hinterlegt.
  secret {
    name  = "database-url"
    value = "postgresql+psycopg://assetmanager:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.vicc.fqdn}:5432/assetdb"
  }

  # Speichert das Passwort der Azure Container Registry als Secret
  # innerhalb der Container App.
  secret {
    name  = "registry-password"
    value = azurerm_container_registry.vicc.admin_password
  }


  # ---------------------------------------------------------------------------
  # Container Registry
  # ---------------------------------------------------------------------------

  # Konfiguriert die Verbindung zur privaten Azure Container Registry,
  # damit Azure Container Apps das Docker-Image laden kann.
  registry {
    server               = azurerm_container_registry.vicc.login_server
    username             = azurerm_container_registry.vicc.admin_username
    password_secret_name = "registry-password"
  }


  # ---------------------------------------------------------------------------
  # Container Template und Skalierung
  # ---------------------------------------------------------------------------

  template {
    # Definiert die minimale und maximale Anzahl der möglichen Replikas.
    #
    # Im Normalbetrieb wird mindestens eine Replica ausgeführt.
    # Bei erhöhter Last kann Azure Container Apps die Anwendung
    # automatisch auf maximal zwei Replikas skalieren.
    min_replicas = 1
    max_replicas = 2

    # -------------------------------------------------------------------------
    # HTTP-basiertes Autoscaling
    # -------------------------------------------------------------------------

    # Die Skalierungsregel überwacht die Anzahl gleichzeitig aktiver
    # HTTP-Anfragen pro Replica.
    #
    # Wird der definierte Schwellenwert überschritten, kann Azure Container
    # Apps automatisch eine zusätzliche Replica starten. Sinkt die Last
    # wieder, kann die Anzahl der Replikas erneut reduziert werden.
    #
    # Der niedrige Schwellenwert von fünf gleichzeitigen Anfragen wurde
    # bewusst für die Entwicklungs- und Testumgebung gewählt, damit das
    # Skalierungsverhalten mit geringer Last getestet werden kann.
    http_scale_rule {
      name                = "http-autoscaling"
      concurrent_requests = "5"
    }

    # -------------------------------------------------------------------------
    # Anwendungscontainer
    # -------------------------------------------------------------------------

    # Konfiguration des eigentlichen Anwendungscontainers.
    container {
      name = "vicc-asset-manager"

      # Das Docker-Image wird aus der zuvor erstellten
      # Azure Container Registry geladen.
      image = "${azurerm_container_registry.vicc.login_server}/vicc-asset-manager:v1"

      # Ressourcen für eine einzelne Container-Instanz.
      cpu    = 0.25
      memory = "0.5Gi"

      # Übergibt die Datenbank-Verbindungszeichenfolge als
      # Umgebungsvariable an die Flask-Anwendung.
      #
      # app.py liest diese anschliessend über DATABASE_URL aus.
      env {
        name        = "DATABASE_URL"
        secret_name = "database-url"
      }
    }
  }


  # ---------------------------------------------------------------------------
  # Netzwerk / Ingress
  # ---------------------------------------------------------------------------

  ingress {
    # Die Anwendung ist über das Internet erreichbar.
    external_enabled = true

    # Flask lauscht innerhalb des Containers auf TCP-Port 5000.
    target_port = 5000

    # Der gesamte eingehende Traffic wird an die aktuellste
    # Revision der Container App weitergeleitet.
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }


  # ---------------------------------------------------------------------------
  # Tags
  # ---------------------------------------------------------------------------

  tags = {
    project     = "VICC Praxisarbeit"
    environment = "dev"
    managed_by  = "Terraform"
  }
}
