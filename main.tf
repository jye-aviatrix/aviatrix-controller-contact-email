resource "aviatrix_controller_email_config" "this" {
  admin_alert_email                   = var.admin_alert_email
  critical_alert_email                = var.critical_alert_email
  security_event_email                = var.security_event_email
  status_change_email                 = var.status_change_email
  status_change_notification_interval = var.status_change_notification_interval
}

# ---------------------------------------------------------------------------
# Admin user + CoPilot service account emails: no provider resource exists, so
# call the controller v2 API with terracurl.
#
# NOTE: the controller answers HTTP 200 even on failure ({"return": false}),
# so every call has a postcondition that checks the "return" field.
# ---------------------------------------------------------------------------
locals {
  api_url = "https://${var.controller_ip}/v2/api"
}

# Fresh login on every plan/apply (data sources are re-read each run).
data "terracurl_request" "login" {
  count = var.update_account_user_emails ? 1 : 0

  name            = "avx_login"
  url             = local.api_url
  method          = "POST"
  headers         = { "Content-Type" = "application/json" }
  request_body    = jsonencode({ action = "login", username = var.controller_username, password = var.controller_password })
  response_codes  = [200]
  skip_tls_verify = true # controller uses a self-signed certificate
  max_retry       = 30
  retry_interval  = 10

  lifecycle {
    postcondition {
      condition     = try(jsondecode(self.response).return, false)
      error_message = "Aviatrix login failed: ${try(jsondecode(self.response).reason, "unparseable response")}"
    }
  }
}

locals {
  cid = var.update_account_user_emails ? sensitive(jsondecode(data.terracurl_request.login[0].response).CID) : ""
}

# Used to skip the CoPilot update when that user does not exist
# (control plane deployed with copilot_initialization = false).
data "terracurl_request" "list_users" {
  count = var.update_account_user_emails ? 1 : 0

  name            = "avx_list_account_users"
  url             = local.api_url
  method          = "POST"
  headers         = { "Content-Type" = "application/json" }
  request_body    = jsonencode({ action = "list_account_users", CID = local.cid })
  response_codes  = [200]
  skip_tls_verify = true
  max_retry       = 3
  retry_interval  = 3

  lifecycle {
    postcondition {
      condition     = try(jsondecode(self.response).return, false)
      error_message = "list_account_users failed: ${try(jsondecode(self.response).reason, "unparseable response")}"
    }
  }
}

locals {
  copilot_user_exists = var.update_account_user_emails ? strcontains(data.terracurl_request.list_users[0].response, "\"${var.copilot_service_account_username}\"") : false
}

# The terracurl requests below are re-created only when one of these inputs changes
# (the CID in the body changes every run, so ignore_changes = all is required).
resource "terraform_data" "account_user_email_inputs" {
  input = {
    controller_ip    = var.controller_ip
    admin_email      = var.admin_user_email
    copilot_email    = var.copilot_user_email
    copilot_username = var.copilot_service_account_username
  }
}

resource "terracurl_request" "admin_user_email" {
  count = var.update_account_user_emails ? 1 : 0

  name            = "set_admin_user_email"
  url             = local.api_url
  method          = "POST"
  headers         = { "Content-Type" = "application/json" }
  request_body    = jsonencode({ action = "edit_account_user", CID = local.cid, username = "admin", what = "email", email = var.admin_user_email })
  response_codes  = [200]
  skip_tls_verify = true
  max_retry       = 3
  retry_interval  = 3

  lifecycle {
    ignore_changes       = all
    replace_triggered_by = [terraform_data.account_user_email_inputs]
    postcondition {
      condition     = try(jsondecode(self.response).return, false)
      error_message = "Updating admin user email failed: ${try(jsondecode(self.response).reason, "unparseable response")}"
    }
  }

  depends_on = [aviatrix_controller_email_config.this]
}

resource "terracurl_request" "copilot_user_email" {
  count = var.update_account_user_emails && local.copilot_user_exists ? 1 : 0

  name            = "set_copilot_user_email"
  url             = local.api_url
  method          = "POST"
  headers         = { "Content-Type" = "application/json" }
  request_body    = jsonencode({ action = "edit_account_user", CID = local.cid, username = var.copilot_service_account_username, what = "email", email = var.copilot_user_email })
  response_codes  = [200]
  skip_tls_verify = true
  max_retry       = 3
  retry_interval  = 3

  lifecycle {
    ignore_changes       = all
    replace_triggered_by = [terraform_data.account_user_email_inputs]
    postcondition {
      condition     = try(jsondecode(self.response).return, false)
      error_message = "Updating CoPilot user email failed: ${try(jsondecode(self.response).reason, "unparseable response")}"
    }
  }

  depends_on = [terracurl_request.admin_user_email]
}
