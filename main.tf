terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.15.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

module "project-services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "10.1.1"

  project_id                  = var.project_id

  activate_apis = [
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com"
  ]
}


resource "google_artifact_registry_repository" "my-repo" {
  depends_on = [
    module.project-services
  ]
  
  provider = google-beta

  project                  = var.project_id

  location = "us-central1"
  repository_id = "cloud-run-hello"
  description = "example docker repository"
  format = "DOCKER"
}

# resource "null_resource" "setup" {
#   provisioner "local-exec" {
#     command = "gcloud auth configure-docker us-central1-docker.pkg.dev"
#   }
# }

resource "null_resource" "update_image" {

  triggers = {
    always_run = "${timestamp()}"
  }


#   provisioner "local-exec" {
#     command = <<EOF
#       cd ..
#       docker build -t \
#         us-central1-docker.pkg.dev/${var.project_id}/cloud-run-hello/cloud-run-hello \
#         -f Dockerfile .
#       docker push \
#         us-central1-docker.pkg.dev/${var.project_id}/cloud-run-hello/cloud-run-hello:latest 
# EOF
#   }
}

data "google_client_config" "default" {}

provider "docker" {

  host = "ssh://localhost:60006"

  registry_auth {
    address  = "us-central1-docker.pkg.dev"
    username = "oauth2accesstoken"
    password = data.google_client_config.default.access_token
  }
}

data "docker_registry_image" "container_image" {

  depends_on = [
    # null_resource.setup,
    null_resource.update_image
  ]

  name = "us-central1-docker.pkg.dev/${var.project_id}/cloud-run-hello/cloud-run-hello"
}

# module "cloud_run_green" {
#   source  = "GoogleCloudPlatform/cloud-run/google"
#   version = "~> 0.1.1"

#   depends_on = [
#   #   null_resource.setup,
#      data.docker_registry_image.container_image
#   ]

#   # Required variables
#   project_id             = var.project_id
#   service_name           = "cloud-run-hello"
#   location               = "us-central1"
#   image                  = "us-central1-docker.pkg.dev/${var.project_id}/cloud-run-hello/cloud-run-hello@${data.docker_registry_image.container_image.sha256_digest}"
#   members                = [
#     "allUsers"
#   ]
  
#   env_vars = [
#     {
#       "name" : "COLOR",
#       "value": "#66FF99"
#     }
#   ]

#   generate_revision_name = false

#   traffic_split          = [
#     {
#       "latest_revision": false,
#       "percent": 100,
#       "revision_name": "cloud-run-hello-green"
#     }
#   ]

# }

# module "cloud_run_blue" {
#   source  = "GoogleCloudPlatform/cloud-run/google"
#   version = "~> 0.1.1"

#   depends_on = [
#   #   null_resource.setup,
#      data.docker_registry_image.container_image,
#      module.cloud_run_green
#   ]

#   # Required variables
#   project_id             = var.project_id
#   service_name           = "cloud-run-hello"
#   location               = "us-central1"
#   image                  = "us-central1-docker.pkg.dev/${var.project_id}/cloud-run-hello/cloud-run-hello@${data.docker_registry_image.container_image.sha256_digest}"
#   members                = [
#     "allUsers"
#   ]
#   generate_revision_name = false
  
#   env_vars = [
#     {
#       "name" : "COLOR",
#       "value": "#D5F3FE"
#     }
#   ]

#   traffic_split          = [
#     {
#       "latest_revision": false,
#       "percent": 75,
#       "revision_name": "cloud-run-hello-blue"
#     },
#     {
#       "latest_revision": false,
#       "percent": 25,
#       "revision_name": "cloud-run-hello-green"
#     }
#   ]

# }

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

# gcloud run deploy cloud-run-hello --image us-central1-docker.pkg.dev/$(gcloud config get-value project)/cloud-run-hello/cloud-run-hello@sha256:eeb7416182d270b1ee9831004fb46b790d480fad600d0597aad0ddf27382b980 \
#     --set-env-vars COLOR=#66FF99 --revision-suffix green --allow-unauthenticated

# resource "google_cloud_run_service" "green" {
#   name     = "cloud-run-hello"
#   location = "us-central1"

#   template {
#     spec {
#       containers {
#         # sha256:eeb7416182d270b1ee9831004fb46b790d480fad600d0597aad0ddf27382b980
#         image = "us-central1-docker.pkg.dev/${var.project_id}/cloud-run-hello/cloud-run-hello@${data.docker_registry_image.container_image.sha256_digest}"
#         env {
#           name = "COLOR"
#           value = "#66FF99"
#         }
#       }
#     }

#     metadata {
#       name = "cloud-run-hello-green"
#     }
#   }

#   autogenerate_revision_name = false

#   traffic {
#     percent         = 100
#     latest_revision = false
#     revision_name   = "cloud-run-hello-green" 
#   }
# }

# resource "google_cloud_run_service_iam_policy" "green" {
#   location    = google_cloud_run_service.green.location
#   project     = google_cloud_run_service.green.project
#   service     = google_cloud_run_service.green.name

#   policy_data = data.google_iam_policy.noauth.policy_data
# }

resource "google_cloud_run_service" "blue" {
  name     = "cloud-run-hello"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "us-central1-docker.pkg.dev/${var.project_id}/cloud-run-hello/cloud-run-hello@${data.docker_registry_image.container_image.sha256_digest}"
        env {
          name = "COLOR"
          value = "#D5F3FEf"
        }
      }
    }

    metadata {
      name = "cloud-run-hello-blue"
    }
  }

  autogenerate_revision_name = false

  traffic {
    percent         = 75
    latest_revision = false
    revision_name   = "cloud-run-hello-green" 
  }

  traffic {
    percent         = 25
    latest_revision = false
    revision_name   = "cloud-run-hello-blue" 
  }
}

resource "google_cloud_run_service_iam_policy" "blue" {
  location    = google_cloud_run_service.blue.location
  project     = google_cloud_run_service.blue.project
  service     = google_cloud_run_service.blue.name

  policy_data = data.google_iam_policy.noauth.policy_data
}