resource "google_cloud_run_v2_service" "tetris" {
  provider = google-beta
  project  = var.serverless_project_id
  name     = var.cloud_run_service_name
  location = var.region

  ingress         = "INGRESS_TRAFFIC_ALL"  ##using default https endpoints aswell as custom domain for just domain route all traffic through LB ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
    
  template {
    service_account = var.cloud_run_sa
    
    containers {
      image = var.image
      # I gave up on secret manager for now and am just putting DB_URL directly in terraform.tfvars and not uploading it to github
      env {
        name = "DB_URL"
        value = var.DB_URL
      }
    }

   vpc_access {
       # Cloud Run v2 expects full resource name: projects/{project}/locations/{region}/connectors/{name}
       connector = google_vpc_access_connector.serverless_connector.id
     # Only route traffic via connector; keeps Internet egress direct from Cloud Run
       egress    = "PRIVATE_RANGES_ONLY"
  }

  #didn't do this in the last project and am now terrified I will accidentally bankrupt my family by running 1000 instances of tetris
    scaling {
      min_instance_count = 0
      max_instance_count = 5
    }
}
}

# Switch IAM to v2
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.serverless_project_id
  location = var.region
  name     = google_cloud_run_v2_service.tetris.name
  role     = "roles/run.invoker"
  member   = "allUsers"       ## if you switch to LB ingress only need to make a SA for load balancer and grant it run invoker instead of allUsers

  depends_on = [google_cloud_run_v2_service.tetris]
}

## Cloud Run consumer service for Eventarc-delivered Pub/Sub messages WILL FAIL WITHOUT A CONTAINER IMAGE TO DEPLOY
resource "google_cloud_run_v2_service" "tetris_db_consumer" {
  provider = google-beta
  project  = var.serverless_project_id
  name     = var.consumer_service_name
  location = var.region

  template {
    service_account = google_service_account.eventarc_invoker.email

    containers {
      image = var.consumer_image
    }
  

  scaling {
    min_instance_count = 0
    max_instance_count = 3
  }
}
}
## past this I have not deployed will fail cause I have no container for cloud events to trigger
## we can do it during presentation if we have time and watch the 2 fail

## Pub/sub topic for event driven Cloud Run GOOD
resource "google_pubsub_topic" "db_events_topic" {
  name    = "db-events"
  project = var.serverless_project_id
}

## Listerner service account binding to allow Cloud Run to pull messages from Pub/Sub GOOD
resource "google_service_account" "listener_gsa" {
  project      = var.serverless_project_id
  account_id   = "db-listener"
  display_name = "DB Notify Listener (publishes to Pub/Sub)"
}

resource "google_pubsub_topic_iam_member" "listener_publisher" {
  project = var.serverless_project_id
  topic   = google_pubsub_topic.db_events_topic.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.listener_gsa.email}"
}

## pull in GKE cluster info to allow Cloud Run to connect to it
data "google_client_config" "default" {}

data "google_container_cluster" "gke" {
  project  = var.serverless_project_id
  name     = var.gke_cluster_name
  location = var.zone
}

provider "kubernetes" {
  host = "https://${data.google_container_cluster.gke.endpoint}"
  cluster_ca_certificate = base64decode(data.google_container_cluster.gke.master_auth[0].cluster_ca_certificate)
  token = data.google_client_config.default.access_token
}

# GOOD
resource "kubernetes_service_account" "listener_ksa" {
  metadata {
    name      = "listener-ksa"
    namespace = "sql-db"
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.listener_gsa.email
    }
  }
}

resource "google_service_account_iam_member" "wi_binding" {
  service_account_id = google_service_account.listener_gsa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.serverless_project_id}.svc.id.goog[sql-db/${kubernetes_service_account.listener_ksa.metadata[0].name}]"
}


## postgres listener deployment on GKE that sends notifications to Pub/Sub topic WILL FAIL WITHOUT A CONTAINER IMAGE TO DEPLOY
resource "kubernetes_deployment" "pg_notify_listener" {
  metadata {
    name      = "pg-notify-listener"
    namespace = "sql-db"
    labels = { app = "pg-notify-listener" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "pg-notify-listener" }
    }
    template {
      metadata {
        labels = { app = "pg-notify-listener" }
      }
      spec {

        service_account_name = kubernetes_service_account.listener_ksa.metadata[0].name

        container {
          name  = "listener"
          image = "northamerica-northeast1-docker.pkg.dev/kaleb-demo-project1/kalebs-repository/pg-listener:latest" ## Image does not exist just using it like placeholder for example

          env {
            name  = "PGHOST"
            value = "10.10.0.5" ## Internal LB IP of Postgres service
          }

          env {
            name  = "PGPORT"
            value = "5432"
          }

          env {
            name  = "PGDATABASE"
            value = "tetrisappdb"
          }

          env {
            name  = "PUBSUB_TOPIC"
            value = google_pubsub_topic.db_events_topic.name
          }

          env {
            name  = "GOOGLE_CLOUD_PROJECT"
            value = var.serverless_project_id
          }

          env {
            name = "LISTEN_CHANNEL"
            value = "db_events"
          }

          # Map secret keys to PGUSER/PGPASSWORD
          env {
            name = "PGUSER"
            value_from {
              secret_key_ref { 
                name = "postgres-secret" 
                key = "username" 
              }
            }
          }
          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref { 
                name = "postgres-secret" 
                key = "password" 
              }
            }
          }
        }
      }
    }
  }
}


## SQL trigger is AI I wrote the actual resource did not know how to make the trigger SHOULD BE GOOD IDK IF THE TRIGGER SQL IS CORRECT
resource "kubernetes_config_map" "pg_triggers_sql" {
  metadata {
    name      = "pg-triggers-sql"
    namespace = "sql-db"
  }
  data = {
    "init.sql" = <<-SQL
      -- Function to build a simple change event payload (customize as needed)
      CREATE OR REPLACE FUNCTION public.emit_change_event() RETURNS trigger AS $$
      DECLARE
        payload jsonb;
        op text;
      BEGIN
        IF TG_OP = 'INSERT' THEN
          op := 'c';
          payload := jsonb_build_object('op', op, 'table', TG_TABLE_NAME, 'new', to_jsonb(NEW));
        ELSIF TG_OP = 'UPDATE' THEN
          op := 'u';
          payload := jsonb_build_object('op', op, 'table', TG_TABLE_NAME, 'old', to_jsonb(OLD), 'new', to_jsonb(NEW));
        ELSIF TG_OP = 'DELETE' THEN
          op := 'd';
          payload := jsonb_build_object('op', op, 'table', TG_TABLE_NAME, 'old', to_jsonb(OLD));
        END IF;

        PERFORM pg_notify('db_events', payload::text);
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql SECURITY DEFINER;

      -- Example: attach to a specific table
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger WHERE tgname = 'trg_emit_change_your_table_ins'
        ) THEN
          CREATE TRIGGER trg_emit_change_your_table_ins
            AFTER INSERT ON Scores
            FOR EACH ROW EXECUTE FUNCTION public.emit_change_event();
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger WHERE tgname = 'trg_emit_change_your_table_upd'
        ) THEN
          CREATE TRIGGER trg_emit_change_your_table_upd
            AFTER UPDATE ON Scores
            FOR EACH ROW EXECUTE FUNCTION public.emit_change_event();
        END IF;

        IF NOT EXISTS (
          SELECT 1 FROM pg_trigger WHERE tgname = 'trg_emit_change_your_table_del'
        ) THEN
          CREATE TRIGGER trg_emit_change_your_table_del
            AFTER DELETE ON Scores
            FOR EACH ROW EXECUTE FUNCTION public.emit_change_event();
        END IF;
      END $$;
    SQL
  }
}






## Kubernetes config map to hold SQL for initializing Postgres triggers GOOD RUNS ONCE TO ADD TRIGGERS
resource "kubernetes_job" "init_pg_triggers" {
  metadata {
    name      = "init-pg-triggers"
    namespace = "sql-db"
  }
   spec {
    ttl_seconds_after_finished = 600
    backoff_limit              = 1
    template {
      metadata { labels = { job = "init-pg-triggers" } }
      spec {
        restart_policy = "Never"
        container {
          name  = "psql"
          image = "postgres:15-alpine"
          command = ["sh","-lc"]
          args = [
            "PGPASSWORD=$PGPASSWORD psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -f /sql/init.sql"
          ]

          env { 
            name = "PGHOST"    
            value = "10.10.0.5" 
           }
          env { 
            name = "PGPORT"     
            value = "5432" 
          }
          env { 
            name = "PGDATABASE" 
            value = "tetrisappdb" 
          }
          env {
            name = "PGUSER"
            value_from { 
              secret_key_ref {
                 name = "postgres-secret" 
                 key = "username" 
                 } 
                }
          }

          env {
            name = "PGPASSWORD"
            value_from { 
              secret_key_ref {
                 name = "postgres-secret"
                  key = "password" 
                  } 
                }
          }

          volume_mount {
            name       = "sql"
            mount_path = "/sql"
            read_only  = true
          }
        }

        volume {
          name = "sql"
          config_map { 
            name = kubernetes_config_map.pg_triggers_sql.metadata[0].name 
          }
        }
      }
    }
  }
}

## event driven cloud run service that triggers on new transfer / update to sql db  LAST WILL FAIL WITHOUT A CONTAINER IMAGE TO DEPLOY

resource "google_service_account" "eventarc_invoker" {
  project      = var.serverless_project_id
  account_id   = "eventarc-invoker"
  display_name = "Eventarc to Cloud Run invoker"
}

resource "google_cloud_run_v2_service_iam_member" "consumer_invoker" {
  project  = var.serverless_project_id
  location = var.region
  name     = google_cloud_run_v2_service.tetris_db_consumer.name       # your consumer service name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.eventarc_invoker.email}"
}

resource "google_eventarc_trigger" "db_events_to_consumer" {
  project  = var.serverless_project_id
  location = var.region
  name     = "tetris-db-events"

  matching_criteria {
    attribute = "type" 
    value     = "google.cloud.pubsub.topic.v1.messagePublished" ## put attribute your app looks for I don't have one so left it generic
  }

  transport {
    pubsub {
      topic = google_pubsub_topic.db_events_topic.id
    }
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.tetris_db_consumer.name       # your consumer service name
      region  = var.region
    }
  }

  service_account = google_service_account.eventarc_invoker.email

  depends_on = [
    google_cloud_run_v2_service_iam_member.consumer_invoker
  ]
}