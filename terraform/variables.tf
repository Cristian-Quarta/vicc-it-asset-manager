# =============================================================================
# VICC IT Asset Manager - Terraform Variablen
# =============================================================================
# In dieser Datei werden Variablen definiert, deren Werte nicht direkt
# in der eigentlichen Infrastrukturkonfiguration hinterlegt werden sollen.
# =============================================================================


# Administratorpasswort für Azure Database for PostgreSQL.
#
# Das Passwort wird bewusst nicht direkt in main.tf gespeichert.
# Der konkrete Wert wird Terraform extern übergeben und gehört nicht
# in das Git-Repository.
#
# Mit "sensitive = true" behandelt Terraform den Wert als sensibel und
# blendet ihn in vielen Ausgaben aus.
variable "postgres_admin_password" {
  description = "Administrator password for Azure PostgreSQL"
  type        = string
  sensitive   = true
}
