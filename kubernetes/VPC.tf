resource "google_compute_network" "shared_vpc" {
  name                    = var.shared_vpc_name
  auto_create_subnetworks = false
  project                 = var.vpc_project_id
}

resource "google_compute_subnetwork" "shared_subnet" {
  name          = "vpc-subnet-gke"
  ip_cidr_range = "10.10.0.0/20"
  secondary_ip_range {
    range_name = "gke-pods"
    ip_cidr_range = "10.20.0.0/14"
  }
  secondary_ip_range {
    range_name = "gke-services"
    ip_cidr_range = "10.15.0.0/20"
  }
  region        = var.region
  network       = google_compute_network.shared_vpc.self_link
  project       = var.vpc_project_id
}

# get project number of the serverless/project that will create the connector
data "google_project" "serverless" {
  project_id = var.serverless_project_id
}

# Allow the Cloud Run/serverless service robot to use the host subnet
resource "google_compute_subnetwork_iam_member" "service_robot_network_user" {
  project    = var.vpc_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.shared_subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.serverless.number}@serverless-robot-prod.iam.gserviceaccount.com"
}

# Allow the VPC Access service agent to use the subnet (needed by connector)
resource "google_compute_subnetwork_iam_member" "vpcaccess_service_agent_network_user" {
  project    = var.vpc_project_id
  region     = var.region
  subnetwork = google_compute_subnetwork.shared_subnet.name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${data.google_project.serverless.number}@gcp-sa-vpcaccess.iam.gserviceaccount.com"
}