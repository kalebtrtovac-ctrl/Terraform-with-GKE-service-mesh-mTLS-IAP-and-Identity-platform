resource "google_monitoring_notification_channel" "email_alert" {
  project      = var.serverless_project_id
  display_name = "email-${var.cloud_run_service_name}"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "cloud_run_5xx" {
  project      = var.serverless_project_id
  display_name = "Cloud Run 5xx errors - ${var.cloud_run_service_name}"
  combiner     = "OR"

  documentation {
    content = "Alert when Cloud Run ${var.cloud_run_service_name} experiences a spike in 5xx responses."
  }

  conditions {
    display_name = "5xx error spike (MQL)"
    condition_monitoring_query_language {
      duration = "300s" # evaluate over 5 minutes
      # MQL: fetch request count for the Cloud Run service; trigger when aggregated 5xx count > threshold
      query = <<-MQL
        fetch cloud_run_revision
        | metric 'run.googleapis.com/request_count'
        | filter 
        (resource.service_name == 'tetris') && (metric.response_code_class =~ '5xx')
        | align rate(1m)
        | every 1m
        | group_by [resource.service_name], [value_request_count: sum(val())]
        | condition value_request_count > 0.1667 "1/s"
      MQL
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email_alert.name
  ]
  user_labels = {
    service = var.cloud_run_service_name
  }
}