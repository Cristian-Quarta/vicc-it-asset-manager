# VICC IT Asset Manager

Der **VICC IT Asset Manager** ist eine einfache cloudbasierte Webanwendung zur Verwaltung von IT-Assets.  
Das Projekt wurde im Rahmen der VICC-Praxisarbeit entwickelt und demonstriert die Bereitstellung einer containerisierten Webanwendung auf Microsoft Azure.

Die Anwendung ermöglicht das Erfassen, Bearbeiten, Anzeigen und Löschen von IT-Assets. Zusätzlich stellt sie eine REST-API zur Verfügung, über welche die gespeicherten Assets im JSON-Format abgerufen werden können.

## Funktionen

Die Webanwendung bietet folgende Funktionen:

- Anzeigen aller IT-Assets
- Erfassen neuer Assets
- Bearbeiten bestehender Assets
- Löschen von Assets
- Persistente Speicherung in PostgreSQL
- REST-API unter `/api/assets`
- Bereitstellung über HTTPS
- Containerisierte Ausführung mit Docker

Ein Asset kann unter anderem folgende Informationen enthalten:

- Hostname
- Typ
- Betriebssystem
- IP-Adresse
- Standort
- Status

## Architektur

Die Anwendung wird vollständig in Microsoft Azure betrieben.

```text
                         Internet
                            │
                          HTTPS
                            │
                            ▼
                 ┌─────────────────────┐
                 │ Azure Container Apps│
                 │                     │
                 │ Flask Webanwendung  │
                 └──────────┬──────────┘
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
┌────────────────────────┐    ┌─────────────────────────┐
│ Azure Container        │    │ Azure Database for      │
│ Registry (ACR)         │    │ PostgreSQL              │
│                        │    │ Flexible Server         │ 
│ Docker Image           │    │                         │
└────────────────────────┘    │ Datenbank: assetdb      │
                              └─────────────────────────┘
```

### Azure-Ressourcen

Für das Projekt werden folgende Azure-Ressourcen verwendet:

| Ressource | Aufgabe |
|---|---|
| Resource Group | Logische Gruppierung aller Projektressourcen |
| Azure Container Registry | Speicherung des Docker-Images |
| Azure Container Apps Environment | Laufzeitumgebung für die Container App |
| Azure Container App | Betrieb der Flask-Webanwendung |
| Azure Database for PostgreSQL Flexible Server | Persistente Speicherung der Asset-Daten |

Alle Ressourcen werden in der Azure-Region **Switzerland North** bereitgestellt.

## Technologien

Das Projekt verwendet folgende Technologien:

- **Python / Flask** – Webanwendung und REST-API
- **Flask-SQLAlchemy** – Datenbankzugriff über ORM
- **PostgreSQL** – relationale Datenbank
- **Docker** – Containerisierung der Anwendung
- **Azure Container Registry** – Speicherung des Container-Images
- **Azure Container Apps** – PaaS-Betrieb des Containers
- **Azure Database for PostgreSQL** – PostgreSQL als DBaaS
- **Terraform** – Infrastructure as Code
- **Git / GitHub** – Versionsverwaltung

## Projektstruktur

```text
vicc-it-asset-manager/
│
├── app/
│   ├── app.py
│   ├── requirements.txt
│   └── templates/
│
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   └── .terraform.lock.hcl
│
├── Dockerfile
├── .dockerignore
├── .gitignore
└── README.md
```

## Infrastructure as Code

Die Azure-Infrastruktur wird mit **Terraform** beschrieben und bereitgestellt.

Dadurch kann die Infrastruktur reproduzierbar erstellt, verändert und wieder entfernt werden.

Der typische Terraform-Ablauf besteht aus:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

Nach Abschluss der Tests kann die bereitgestellte Infrastruktur wieder entfernt werden:

```bash
terraform destroy
```

Sensitive Informationen wie Datenbankpasswörter werden nicht im Git-Repository gespeichert.  
Lokale Terraform-Variablen und State-Dateien werden über `.gitignore` ausgeschlossen.

## Containerisierung

Die Flask-Anwendung wird als Docker-Image gebaut:

```bash
docker build -t vicc-asset-manager:v1 .
```

Anschliessend wird das Image für die Azure Container Registry getaggt:

```bash
docker tag vicc-asset-manager:v1 \
  acrviccassetmanager.azurecr.io/vicc-asset-manager:v1
```

und in die Registry übertragen:

```bash
docker push acrviccassetmanager.azurecr.io/vicc-asset-manager:v1
```

Azure Container Apps verwendet anschliessend dieses Image für die Bereitstellung der Webanwendung.

## Datenbank

Während der lokalen Entwicklung wurde PostgreSQL lokal betrieben.

Für den Betrieb in Azure wird **Azure Database for PostgreSQL Flexible Server** eingesetzt. Die Anwendung erhält die Datenbankverbindung über die Umgebungsvariable:

```text
DATABASE_URL
```

Dadurch sind Anwendung und Datenbank voneinander getrennt.

Die Daten bleiben auch dann erhalten, wenn der Container neu gestartet oder ersetzt wird.

## Skalierung

Für die Azure Container App ist eine Skalierung zwischen einer und zwei Replikas vorgesehen:

```hcl
min_replicas = 1
max_replicas = 2
```

Azure Container Apps kann dadurch zusätzliche Instanzen der Anwendung bereitstellen.

## Funktionstest

Die Anwendung wurde erfolgreich über die öffentliche HTTPS-Adresse der Azure Container App getestet.

Dabei wurden unter anderem folgende Tests durchgeführt:

- Aufruf der Webanwendung über einen PC
- Aufruf über ein externes Smartphone
- Erfassen eines Assets über das Smartphone
- Anzeige desselben Assets nach Aktualisierung auf dem PC
- Bearbeiten und Löschen von Assets
- Abruf der Assets über `/api/assets`
- Persistente Speicherung in Azure PostgreSQL

Damit wurde die vollständige Verbindung zwischen Client, Container App und Datenbank verifiziert.

## Sicherheit

Im Projekt wurden unter anderem folgende grundlegende Sicherheitsmassnahmen berücksichtigt:

- HTTPS für den externen Zugriff
- Datenbankpasswort nicht im Repository gespeichert
- Verwendung sensitiver Terraform-Variablen
- Datenbankverbindung über ein Container-App-Secret
- Trennung von Anwendung, Container Registry und Datenbank

Für eine produktive Umgebung könnten zusätzliche Massnahmen wie Private Endpoints, Managed Identities und eine restriktivere Netzwerkkonfiguration umgesetzt werden.

## Autor

**Cristian Quarta**

Praxisarbeit VICC  
Informatiker HF – Plattformentwicklung
