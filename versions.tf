terraform {
  required_version = ">= 1.5"
  required_providers {
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "8.1.20"
    }
    terracurl = {
      source  = "devops-rob/terracurl"
      version = "1.2.1"
    }
  }
}

# Credentials come from variables (set via TF_VAR_* env vars, never commit the password).
provider "aviatrix" {
  controller_ip           = var.controller_ip
  username                = var.controller_username
  password                = var.controller_password
  skip_version_validation = false
}
