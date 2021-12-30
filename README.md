# Example: Traffic splitting for [Cloud Run](cloud.run) with Terraform

Cloud Run allows to create multiple [revisions](https://cloud.google.com/run/docs/resource-model#revisions) of a [service](https://cloud.google.com/run/docs/resource-model#services) and split traffic between revisions.

The Terraform resource of Cloud Run allows to [leverage this capability](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_service#example-usage---cloud-run-service-traffic-split).

## Implementation

Unfortunately it is not possible to manage multipe revisions of the same service via Terraform as the following example from the docs shows.

```
resource "google_cloud_run_service" "default" {
  name     = "cloudrun-srv"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
    }
    metadata {
      name = "cloudrun-srv-green"
    }
  }

  traffic {
    percent       = 25
    revision_name = "cloudrun-srv-green"
  }

  traffic {
    percent       = 75
    # This revision needs to already exist
    revision_name = "cloudrun-srv-blue"
  }
}
```

As the comment states "This revision needs to already exist". But also with an existing service the Terraform resource does not work.

