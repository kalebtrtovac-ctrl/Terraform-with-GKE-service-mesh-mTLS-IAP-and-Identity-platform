# Allow Cloud Run VPC connector range to reach PostgreSQL on GKE nodes
resource "google_compute_firewall" "allow_postgres_from_serverless" {
  name    = "allow-postgres-from-serverless"
  network = var.shared_vpc_name
  project = var.vpc_project_id

  direction = "INGRESS"
  priority  = 1000

  # Use the connector's IP range to avoid hard-coding CIDR
  source_ranges = [google_vpc_access_connector.serverless_connector.ip_cidr_range]
  target_tags   = ["gke-sql-db-nodes"]

  # GKE Internal LoadBalancer forwards to nodePort on the nodes (30000-32767).
  # Allow both the service port (5432) and the NodePort range for data plane traffic.
  allow {
    protocol = "tcp"
    ports    = ["5432", "30000-32767"]
  }
}
