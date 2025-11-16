variable "serverless_project_id" {
  description = "The project where cloud run is going to be deployed."
  type        = string
}

variable "cloud_run_sa" {
  description = "Service account to be used on Cloud Run."
  type        = string
}

variable "vpc_project_id" {
  description = "The project where shared vpc is."
  type        = string
  default = "kaleb-demo-project1"
}

variable "shared_vpc_name" {
  description = "Shared VPC name which is going to be re-used to create Serverless Connector."
  type        = string
  default = "shared-vpc"
}

variable "kms_project_id" {
  description = "The project where KMS will be created."
  type        = string
}

variable "domain" {
  description = "Domain list to run on the load balancer. Used if `ssl` is `true`."
  type        = list(string)
}

variable "policy_for" {
  description = "Policy Root: set one of the following values to determine where the policy is applied. Possible values: [\"project\", \"folder\", \"organization\"]."
  type        = string
}

variable "folder_id" {
  description = "The folder ID to apply the policy to."
  type        = string
  default     = ""
}

variable "organization_id" {
  description = "The organization ID to apply the policy to."
  type        = string
  default     = ""
}

variable "resource_names_suffix" {
  description = "A suffix to concat in the end of the network resources names."
  type        = string
  default     = ""
}

variable "ip_cidr_range" {
  description = "The range of internal addresses that are owned by the subnetwork and which is going to be used by VPC Connector. For example, 10.0.0.0/28 or 192.168.0.0/28. Ranges must be unique and non-overlapping within a network. Only IPv4 is supported."
  type        = string
}

variable "create_cloud_armor_policies" {
  type        = bool
  description = "When `true`, the terraform will create the Cloud Armor policies. When `false`, the user must provide their own Cloud Armor name in `cloud_armor_policies_name`."
  default     = false ## couldn't update quota to set 
}

variable "cloud_armor_policies_name" {
  type        = string
  description = "Cloud Armor policy name already created in the project. If `create_cloud_armor_policies` is `false`, this variable must be provided, If `create_cloud_armor_policies` is `true`, this variable will be ignored."
  default     = ""
}

variable "region" {
    type = string
    description = "The region to deploy resources in."
}

variable "cloud_run_service_name" {
    type        = string
    description = "The name of the Cloud Run service to be created."
}

variable "image" {
  description = "Container image to deploy (Artifact Registry path)."
  type        = string
}

variable "apex_domain" {
  description = "The apex domain for which a managed zone will be created in Cloud DNS."
  type        = string
}

variable "alert_email" {
  description = "email address for monitoring alerts"
  type = string
  default = "your-email-address@domain.com"
}

variable "gke_cluster_name" {
  description = "name of GKE cluster"
  type = string
  default = "yourclustername"
}

variable "con_cidr_range" {
  description = "The range of internal addresses that are owned by the subnetwork and which is going to be used by VPC Connector."
  type        = string
}

variable "DB_URL" {
  description = "Database connection URL to be used by the Cloud Run service."
  type        = string
}

variable "zone" {
  description = "The zone to deploy resources in."
  type        = string
}


variable "groups" {
  description = <<EOT
  Groups which will have roles assigned.
  The Serverless Administrators email group which the following roles will be added: Cloud Run Admin, Compute Network Viewer and Compute Network User.
  The Serverless Security Administrators email group which the following roles will be added: Cloud Run Viewer, Cloud KMS Viewer and Artifact Registry Reader.
  The Cloud Run Developer email group which the following roles will be added: Cloud Run Developer, Artifact Registry Writer and Cloud KMS CryptoKey Encrypter.
  The Cloud Run User email group which the following roles will be added: Cloud Run Invoker.
  EOT

  type = object({
    group_serverless_administrator          = optional(string, null)
    group_serverless_security_administrator = optional(string, null)
    group_cloud_run_developer               = optional(string, null)
    group_cloud_run_user                    = optional(string, null)
  })

  default = {}
}

# Consumer Cloud Run service variables (for Eventarc destination)
variable "consumer_service_name" {
  description = "The name of the Cloud Run consumer service that receives Eventarc events."
  type        = string
  default     = "tetris-db-consumer"
}

variable "consumer_image" {
  description = "Container image for the consumer Cloud Run service (Artifact Registry path)."
  type        = string
}