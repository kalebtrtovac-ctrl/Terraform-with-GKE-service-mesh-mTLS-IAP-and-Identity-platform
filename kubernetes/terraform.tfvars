cloud_run_sa          = " kaleb-demo-service@kaleb-demo-projectgke-477618.iam.gserviceaccount.com"
domain                = ["www.kalebdemo.ca"]      # replace with your domain
ip_cidr_range         = "10.8.0.0/28"
kms_project_id        = "kaleb-demo-projectgke-477618 "
vpc_project_id        = "kaleb-demo-projectgke-477618"
serverless_project_id = "kaleb-demo-projectgke-477618"
shared_vpc_name       = "shared-vpc-gke"
resource_names_suffix = "dev"
image                 = "northamerica-northeast1-docker.pkg.dev/kaleb-demo-project1/kalebs-repository/tetris:latest"
apex_domain           = "kalebdemo.ca"
cloud_run_service_name = "tetris"
region                = "northamerica-northeast1"
zone                 = "northamerica-northeast1-b"
alert_email           = "kaleb.trtovac@gmail.com"
policy_for            = "none"
billing_account_id = "enter your billing account ID" ## replace with your billing account ID 
gke_cluster_name = "kaleb-demo-gke-cluster"  ## replace with your GKE cluster name
## Remove Billing account when push to github 