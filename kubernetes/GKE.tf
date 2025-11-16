
# deploy GKE cluster with a dedicated node pool for SQL database pods

resource "google_container_cluster" "primary" {
    name = var.gke_cluster_name
    location = var.zone
    remove_default_node_pool = true
    initial_node_count = 1
    network = google_compute_network.shared_vpc.self_link
    subnetwork = google_compute_subnetwork.shared_subnet.self_link

      ip_allocation_policy {
        cluster_secondary_range_name = "gke-pods"
        services_secondary_range_name = "gke-services"
      }  

    deletion_protection = false                # Allow terraform destroy to clean up this cluster (don't lock it)

    # Enable Workload Identity to let K8s service accounts impersonate GCP service accounts
  workload_identity_config {
    workload_pool = "${local.credentials.project_id}.svc.id.goog"  
   
  }

  private_cluster_config {
     enable_private_nodes    = true              # No public IPs on nodes
  }
}

# Create a dedicated node pool for SQL database pods

resource "google_container_node_pool" "sql_node_pool1" {
  name     = "sql-node-pool1"                        # Clean, non-redundant node pool name
  location = var.zone                                 # Same region as the cluster
  cluster  = google_container_cluster.primary.name

  node_config {
    machine_type = "e2-small"                        # Machine type for the nodes
    disk_size_gb = 20                                 # 20GB boot disk prolly overkill for my SQL db but whatever
    image_type    = "COS_CONTAINERD"                  # Default hardened image
    labels = {                                        
      role = "sql-db"
    }
    tags   = ["gke-sql-db-nodes"]                    # Network tag for firewall targeting
    taint {                                           # Taint so only tolerated DB pods land here
      key    = "dedicated"
      value  = "sql"
      effect = "NO_SCHEDULE"
    }
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  autoscaling {
    min_node_count = 1     # Scale down to 1 node during low usage
    max_node_count = 2     # Scale up to 2 nodes under load
  }

  initial_node_count = 1   # Start with 1 node initially (autoscaler will take over after)
}

## for system pods like kube-dns, metrics-server, etc.
resource "google_container_node_pool" "system_pool" {
  name     = "system-pool"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  node_config {
    machine_type = "e2-small"
    disk_size_gb = 20
    image_type   = "COS_CONTAINERD"
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
    labels = {
      role = "system"
    }
  }

  autoscaling {
    min_node_count = 1
    # Allow autoscaler to add capacity for critical system pods (e.g., kube-dns)
    max_node_count = 3
  }

  initial_node_count = 1
}