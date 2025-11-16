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