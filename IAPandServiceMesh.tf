## would add these to variables.tf and define in tfvars file but this is an example of how I could automate it I did not do this
## I did it from the cloud console cause it was faster to learn and test that way
## I do not know how to automate the OAuth client creation with terraform yet don't know if it's possible or if its useful cause it be so different every deployment
## assumes ouath client created already

variable "iap_client_id" {
  description = "OAuth 2.0 client ID (Web app) used by IAP."
  type        = string
  sensitive   = true
}
variable "iap_client_secret" {
  description = "OAuth 2.0 client secret used by IAP."
  type        = string
  sensitive   = true
}
variable "iap_access_members" {
  description = "Principals allowed through IAP (e.g., user:gmail-user@gmail.com)."
  type        = list(string)
  default     = ["user:you@gmail.com"]
}

## edit the backend service to enable IAP and disable cdn in networking.tf
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

  iap {
    enabled = true
    oauth2_client_id = var.iap_client_id
    oauth2_client_secret = var.iap_client_secret
  }

  enable_cdn = false 
}

## from here I'd have to manually go to IAP tell it to use external authentication, tell it to setup a login page for me, copy the login url
## go to identity platform, add a provider, paste the loginurl/__/auth/handler, client id and secret

## could not figure out fleet and service mesh automation so did this part manually
## could have a bunch of null resoureces to run kubectl and gcloud commands but that seems messy and I'd have to set dependencies to ensure order
## so just did it manually this is the commands I used below

gcloud services enable mesh.googleapis.com gkehub.googleapis.com compute.googleapis.com monitoring.googleapis.com logging.googleapis.com iam.googleapis.com cloudtrace.googleapis.com --project kaleb-demo-projectgke-477618 

gcloud container clusters get-credentials kaleb-demo-gke-cluster --zone northamerica-northeast1-b --project kaleb-demo-projectgke-477618 

gcloud container fleet memberships register kaleb-demo-gke-cluster --gke-cluster=northamerica-northeast1-b/kaleb-demo-gke-cluster --enable-workload-identity --project kaleb-demo-projectgke-477618

gcloud container fleet mesh enable --project kaleb-demo-projectgke-477618

# Label namespaces you want in the mesh (add more as needed)
kubectl label namespace default istio.io/rev=asm-managed --overwrite
kubectl label namespace sql-db istio.io/rev=asm-managed --overwrite


## restart workloads to get sidecar injected
kubectl rollout restart deploy -n default
kubectl rollout restart statefulset -n sql-db
kubectl rollout status deploy -n default --timeout=120s
kubectl rollout status statefulset -n sql-db --timeout=120s


## sidecar injection broke my shit the e2-small was to weak to handle the overhead injection brought needed to update my cluster to e2-medium

gcloud container node-pools update sql-node-pool1 --cluster kaleb-demo-gke-cluster --zone northamerica-northeast1-b --machine-type e2-medium

## verify pods have sidecar AI gave me this command to check
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name} -> {range .spec.containers[*]}{.name},{end}{"`n"}{end}'


## write the 2 below yaml files to set mTLS to permissive first then strict

##Permissive mTLS OPTIONAL JUST DOING THIS FOR TESTING DON'T WANT TO BREAK ANYTHING
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: PERMISSIVE
## apply it

kubectl apply -f permissive-mtls.yaml

## verify workloads still running
kubectl get pods -n istio-system

## strict mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT

## apply it
kubectl apply -f strict-mtls.yaml

## apply this yaml to allow cloud run to communicate with the sql db in gke
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: postgres-allow-plaintext-5432
  namespace: sql-db
spec:
  selector:
    matchLabels:
      app: postgres
  # Keep STRICT for all other ports of this workload
  mtls:
    mode: STRICT
  # Allow non-mTLS on Postgres port 5432
  portLevelMtls:
    5432:
      mode: PERMISSIVE

## apply it
kubectl apply -f allow-plaintext-postgres.yaml