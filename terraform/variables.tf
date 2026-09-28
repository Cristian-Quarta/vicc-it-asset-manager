variable "postgres_admin_password" {
  description = "Administrator password for Azure PostgreSQL"
  type        = string
  sensitive   = true
}
