terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.15.0"
    }

    google = {
      version = "3.90.1"
    }
  }
}

locals {
  service-repo = "https://github.com/jeremysolarz/cloud-run-hello.git"
  service-name = "cloud-run-hello"
  region       = "us-central1"
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

  location = local.region
  repository_id = local.service-name
  description = "example docker repository"
  format = "DOCKER"
}

resource "null_resource" "setup" {
   provisioner "local-exec" {
     command = "gcloud auth configure-docker ${local.region}-docker.pkg.dev"
   }
}

resource "null_resource" "update_image" {

  depends_on = [
    null_resource.setup
  ]

  triggers = {
    always_run = "${timestamp()}"
  }


  provisioner "local-exec" {
     command = <<EOF
       rm -rf service-repo
       git clone ${local.service-repo} service-repo
       cd service-repo
       docker build -t \
         ${local.region}-docker.pkg.dev/${var.project_id}/${local.service-name}/${local.service-name} \
         -f Dockerfile .
       docker push \
         ${local.region}-docker.pkg.dev/${var.project_id}/${local.service-name}/${local.service-name}
EOF
  }
}

data "google_client_config" "default" {}

provider "docker" {

  host = "ssh://localhost:60006"
  
  registry_auth {
    address  = "${local.region}-docker.pkg.dev"
    username = "oauth2accesstoken"
    password = data.google_client_config.default.access_token
  }
}

data "docker_registry_image" "container_image" {

  depends_on = [
    null_resource.setup,
    null_resource.update_image
  ]

  name = "${local.region}-docker.pkg.dev/${var.project_id}/${local.service-name}/${local.service-name}"
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "null_resource" "green" {

   provisioner "local-exec" {
     command = <<EOF
     gcloud run deploy ${local.service-name} \
     --image ${local.region}-docker.pkg.dev/${var.project_id}/${local.service-name}/${local.service-name}@${data.docker_registry_image.container_image.sha256_digest} \
     --set-env-vars COLOR=#66FF99 --revision-suffix green --allow-unauthenticated
EOF
   }
}

resource "google_cloud_run_service" "blue" {
  name     = local.service-name
  location = local.region

  depends_on = [
    null_resource.green
  ]

  template {
    spec {
      containers {
        image = "${local.region}-docker.pkg.dev/${var.project_id}/${local.service-name}/${local.service-name}@${data.docker_registry_image.container_image.sha256_digest}"
        env {
          name = "COLOR"
          value = "#D5F3FEf"
        }
      }
    }

    metadata {
      name = "${local.service-name}-blue"
    }
  }

  autogenerate_revision_name = false

  traffic {
    percent         = 25
    latest_revision = false
    revision_name   = "${local.service-name}-blue" 
  }

  traffic {
    percent         = 75
    latest_revision = false
    revision_name   = "${local.service-name}-green" 
  }
}

resource "google_cloud_run_service_iam_policy" "blue" {
  location    = google_cloud_run_service.blue.location
  project     = google_cloud_run_service.blue.project
  service     = google_cloud_run_service.blue.name

  policy_data = data.google_iam_policy.noauth.policy_data
}