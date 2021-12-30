# Example: Traffic splitting for [Cloud Run](cloud.run) with Terraform

Cloud Run allows to create multiple revisions of a service and split traffic between revisions.

The Terraform resource of Cloud Run allows to [leverage this capability](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_service#example-usage---cloud-run-service-traffic-split).