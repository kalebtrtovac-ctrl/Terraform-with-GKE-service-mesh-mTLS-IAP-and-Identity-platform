locals {
  suffix = var.resource_names_suffix == "" ? "" : "-${var.resource_names_suffix}"
  # derive apex domain from first domain entry (www.kalebdemo.com -> kalebdemo.com)
  apex = var.apex_domain
}

# Reserve an external IP for the HTTPS load balancer
resource "google_compute_global_address" "website" {
  name    = "website-lb-ip"
  project = var.serverless_project_id
}

# Google-managed SSL cert for the domain(s)
resource "google_compute_managed_ssl_certificate" "website_cert" {
  provider = google-beta
  name     = "website-cert"
  project  = var.serverless_project_id
  
  managed {
    domains = var.domain
  }
}

# Serverless NEG pointing to Cloud Run service
resource "google_compute_region_network_endpoint_group" "serverless_neg" {
  name                  = "neg-${var.cloud_run_service_name}${local.suffix}"
  region                = var.region
  project               = var.serverless_project_id
  network_endpoint_type = "SERVERLESS"

  cloud_run {
    service = var.cloud_run_service_name 
  }
}

# Backend service that uses the serverless NEG
resource "google_compute_backend_service" "lb_backend" {
  name                  = "bs-${var.cloud_run_service_name}${local.suffix}"
  project               = var.serverless_project_id
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL"
  timeout_sec           = 30



  backend {
    group = google_compute_region_network_endpoint_group.serverless_neg.id
  }

  log_config {
    enable = true
  }

  # Cache static content at the edge to cut Cloud Run traffic/cost and add resiliency
  enable_cdn = true
  cdn_policy {
    # prefer origin headers so your app controls cache behavior
    cache_mode = "USE_ORIGIN_HEADERS"

    negative_caching = true
    negative_caching_policy {
      code = 404
      ttl  = 60
    }
    negative_caching_policy {
      code = 501
      ttl  = 10
    }

    # required: specify a cache_key_policy so the backend knows what to include in cache keys
    cache_key_policy {
      include_protocol      = true
      include_host          = true
      include_query_string  = false
      include_http_headers  = []
      include_named_cookies = []
    }
  }
  
}

# URL map -> route all traffic to the backend
resource "google_compute_url_map" "url_map" {
  name    = "urlmap-${var.cloud_run_service_name}"
  project = var.serverless_project_id

  default_service = google_compute_backend_service.lb_backend.self_link
}

# HTTPS proxy using the managed certificate
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "https-proxy-${var.cloud_run_service_name}${local.suffix}"
  project          = var.serverless_project_id
  url_map          = google_compute_url_map.url_map.self_link
  ssl_certificates = [google_compute_managed_ssl_certificate.website_cert.id]
}

# Global forwarding rule accepting HTTPS
resource "google_compute_global_forwarding_rule" "https_forwarding" {
  name                  = "https-forwarding-${var.cloud_run_service_name}${local.suffix}"
  project               = var.serverless_project_id
  ip_address            = google_compute_global_address.website.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.https_proxy.self_link
  load_balancing_scheme = "EXTERNAL"
}

# Create / ensure Cloud DNS managed zone for the apex domain
# Might comment this out and make the zone and register domain on the cloud console so I can more clearly see the billing and so I don't need to rerun terraform apply if cert fails
resource "google_dns_managed_zone" "kalebzone" {
  name        = "dns-zone-kalebzone"
  dns_name    = "${local.apex}." # required trailing dot
  project     = var.serverless_project_id
  description = "Managed zone for ${local.apex}"
}

# Create A record(s) that point each requested domain to the LB IP
resource "google_dns_record_set" "website" {
  for_each     = toset(var.domain)
  project      = var.serverless_project_id
  managed_zone = google_dns_managed_zone.kalebzone.name
  name         = "test.${local.apex}."   # test.kalebdemo.ca  # required trailing dot
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.website.address]
}




# may need to terraform apply twice to get cert provisioned and LB working 
# certs take 20-30 minutes to issue and might go from provisioning -> fail during that time the dns zone and domain need to be properly set up

# Serverless VPC Access connector so Cloud Run can use your VPC
resource "google_vpc_access_connector" "serverless_connector" {
  name          = "connector-${var.cloud_run_service_name}${local.suffix}"
  project       = var.serverless_project_id
  region        = var.region
  min_throughput = 200  # in Mbps; adjust as needed
  max_throughput = 500  # in Mbps; adjust as needed
  # Change network if you use a non-default VPC (e.g. "my-vpc")
  network       = var.shared_vpc_name

  # Small CIDR block reserved for connector instances; adjust if this overlaps your subnets

  ip_cidr_range = var.con_cidr_range # hard coded for simplicity; consider making this a variable
}

output "serverless_vpc_connector_name" {
  value       = google_vpc_access_connector.serverless_connector.name
  description = "Name of the Serverless VPC Access connector. Use this when attaching the connector to your Cloud Run service."
}


## networking path Internet > external https LB > Cloud Run with VPC connector > Internal LB (on GKE) > Postgres on GKE nodes