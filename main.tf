resource "aviatrix_controller_email_config" "this" {
  admin_alert_email                   = var.admin_alert_email
  critical_alert_email                = var.critical_alert_email
  security_event_email                = var.security_event_email
  status_change_email                 = var.status_change_email
  status_change_notification_interval = var.status_change_notification_interval
}

# Admin user + CoPilot service account emails: no provider resource, so run the API script.
# Re-runs only when one of the emails (or the target) changes.
resource "terraform_data" "account_user_emails" {
  count = var.update_account_user_emails ? 1 : 0

  triggers_replace = {
    controller_ip    = var.controller_ip
    admin_email      = var.admin_user_email
    copilot_email    = var.copilot_user_email
    copilot_username = var.copilot_service_account_username
  }

  provisioner "local-exec" {
    interpreter = ["pwsh", "-NoProfile", "-NonInteractive", "-Command"]
    command     = "& '${path.module}/Update-AvxAccountUserEmail.ps1' -ControllerIp $env:AVX_IP -Username $env:AVX_USER -AdminEmail $env:AVX_ADMIN_EMAIL -CopilotEmail $env:AVX_COPILOT_EMAIL -CopilotUsername $env:AVX_COPILOT_USER"
    environment = {
      AVX_IP            = var.controller_ip
      AVX_USER          = var.controller_username
      AVX_PASSWORD      = var.controller_password # read by the script from env, not the command line
      AVX_ADMIN_EMAIL   = var.admin_user_email
      AVX_COPILOT_EMAIL = var.copilot_user_email
      AVX_COPILOT_USER  = var.copilot_service_account_username
    }
  }

  depends_on = [aviatrix_controller_email_config.this]
}
