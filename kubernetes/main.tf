provider "google" {
  project     = local.credentials.project_id
  credentials = file("../kaleb-demo-projectgke-477618-d9d2d70ce8c4.json")  ##need to change file when I create new project

}

## beta if I want SSL cert
provider "google-beta" {
  project     = local.credentials.project_id
  credentials = file("../kaleb-demo-projectgke-477618-d9d2d70ce8c4.json") ##need to change file when I create new project
}

## local variables to be used everywhere to keep this shit clean
# parses service acct key file
locals {
  credentials           = jsondecode(file("../kaleb-demo-projectgke-477618-d9d2d70ce8c4.json"))  ##need to change file when I create new project
  service_account_email = local.credentials.client_email
}


## to create a service account couldn't figure out how to automate it and use to authenticate to enable APIS

#resource "google_service_account" "service_account" {
 # project = var.vpc_project_id
  #account_id   = "kaleb-demo-service"
  #display_name = "Service Account"
  #email        = var.cloud_run_sa
#}


## set a budget / billing alert

data "google_billing_account" "account" {
  billing_account = var.billing_account_id
}

data "google_project" "project" {
  project_id = var.serverless_project_id
}

resource "google_billing_budget" "budget" {
  billing_account = data.google_billing_account.account.id
  display_name    = "Billing Budget"

  budget_filter {
    projects = ["projects/${data.google_project.project.number}"]
  }

  amount {
    specified_amount {
      currency_code = "CAD"
      units         = "100"
    }
  }
  # alert at $50 $70 $100
  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.7
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.notification_channel.id,
    ]
    disable_default_iam_recipients = true
  }
}

resource "google_monitoring_notification_channel" "notification_channel" {
  display_name = "Example Notification Channel"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}