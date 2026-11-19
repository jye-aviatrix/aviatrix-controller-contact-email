# ---- Controller connection ----
variable "controller_ip" {
  description = "Public (or reachable) IP / FQDN of the Aviatrix controller."
  type        = string
}

variable "controller_username" {
  description = "Controller admin login used by the provider and the API script."
  type        = string
  default     = "admin"
}

variable "controller_password" {
  description = "Controller admin password. Supply via TF_VAR_controller_password."
  type        = string
  sensitive   = true
}

# ---- Notification emails (aviatrix_controller_email_config; all four are required by the provider) ----
variable "admin_alert_email" {
  description = "Email for important account and certificate information."
  type        = string
}

variable "critical_alert_email" {
  description = "Email for field notices and critical notices."
  type        = string
}

variable "security_event_email" {
  description = "Email for security and CVE notifications."
  type        = string
}

variable "status_change_email" {
  description = "Email for system/tunnel status notifications."
  type        = string
}

variable "status_change_notification_interval" {
  description = "Status change notification interval in seconds."
  type        = number
  default     = 60
}

# ---- Account user emails (updated through the v2 API; no Terraform resource exists) ----
variable "admin_user_email" {
  description = "Email address of the controller 'admin' user."
  type        = string
}

variable "copilot_user_email" {
  description = "Email address of the CoPilot service account user."
  type        = string
}

variable "copilot_service_account_username" {
  description = "Username of the CoPilot service account user on the controller."
  type        = string
  default     = "copilot_service_account"
}

variable "update_account_user_emails" {
  description = "Set false to skip the API script (admin / copilot user emails)."
  type        = bool
  default     = true
}
