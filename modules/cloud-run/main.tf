/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

locals {
  _vpcaccess_annotation = (
    local.vpc_connector_create
    ? {
      "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.0.id
    }
    : (
      var.revision_annotations.vpcaccess_connector == null
      ? {}
      : {
        "run.googleapis.com/vpc-access-connector" = (
          var.revision_annotations.vpcaccess_connector
        )
      }
    )
  )
  annotations = merge(
    var.ingress_settings == null ? {} : {
      "run.googleapis.com/ingress" = var.ingress_settings
    }
  )
  prefix = var.prefix == null ? "" : "${var.prefix}-"
  revision_annotations = merge(
    var.revision_annotations.autoscaling == null ? {} : {
      "autoscaling.knative.dev/maxScale" = (
        var.revision_annotations.autoscaling.max_scale
      )
    },
    var.revision_annotations.autoscaling.min_scale == null ? {} : {
      "autoscaling.knative.dev/minScale" = (
        var.revision_annotations.autoscaling.min_scale
      )
    },
    length(var.revision_annotations.cloudsql_instances) == 0 ? {} : {
      "run.googleapis.com/cloudsql-instances" = (
        join(",", var.revision_annotations.cloudsql_instances)
      )
    },
    local._vpcaccess_annotation,
    var.revision_annotations.vpcaccess_egress == null ? {} : {
      "run.googleapis.com/vpc-access-egress" = (
        var.revision_annotations.vpcaccess_egress
      )
    },
  )
  revision_name = (
    try(var.revision_name, null) == null
    ? null
    : "${var.name}-${var.revision_name}"
  )
  service_account_email = (
    var.service_account_create
    ? (
      length(google_service_account.service_account) > 0
      ? google_service_account.service_account[0].email
      : null
    )
    : var.service_account
  )
  vpc_connector_create = var.vpc_connector_create != null
}

resource "google_vpc_access_connector" "connector" {
  count   = local.vpc_connector_create ? 1 : 0
  project = var.project_id
  name = (
    var.vpc_connector_create.name != null
    ? var.vpc_connector_create.name
    : var.name
  )
  region         = var.region
  ip_cidr_range  = var.vpc_connector_create.ip_cidr_range
  network        = var.vpc_connector_create.vpc_self_link
  machine_type   = var.vpc_connector_create.machine_type
  max_instances  = var.vpc_connector_create.instances.max
  max_throughput = var.vpc_connector_create.throughput.max
  min_instances  = var.vpc_connector_create.instances.min
  min_throughput = var.vpc_connector_create.throughput.min
}

resource "google_cloud_run_service" "service" {
  provider = google-beta
  project  = var.project_id
  location = var.region
  name     = "${local.prefix}${var.name}"

  template {
    spec {
      container_concurrency = var.container_concurrency
      service_account_name  = local.service_account_email
      timeout_seconds       = var.timeout_seconds
      dynamic "containers" {
        for_each = var.containers
        content {
          image   = containers.value.image
          args    = containers.value.args
          command = containers.value.command
          dynamic "env" {
            for_each = containers.value.env
            content {
              name  = env.key
              value = env.value.from_key != null ? null : env.value.value
              dynamic "value_from" {
                for_each = env.value.from_key != null ? [""] : []
                content {
                  secret_key_ref {
                    key  = env.value.from_key.key
                    name = env.value.from_key.name
                  }
                }
              }
            }
          }
          dynamic "liveness_probe" {
            for_each = containers.value.liveness_probe == null ? [] : [""]
            content {
              failure_threshold     = containers.value.liveness_probe.failure_threshold
              initial_delay_seconds = containers.value.liveness_probe.initial_delay_seconds
              period_seconds        = containers.value.liveness_probe.period_seconds
              timeout_seconds       = containers.value.liveness_probe.timeout_seconds
              dynamic "grpc" {
                for_each = (
                  containers.value.liveness_probe.action.grpc == null ? [] : [""]
                )
                content {
                  port    = containers.value.liveness_probe.action.grpc.port
                  service = containers.value.liveness_probe.action.grpc.service
                }
              }
              dynamic "http_get" {
                for_each = (
                  containers.value.liveness_probe.action.http_get == null ? [] : [""]
                )
                content {
                  path = containers.value.liveness_probe.action.http_get.path
                  dynamic "http_headers" {
                    for_each = (
                      containers.value.liveness_probe.action.http_get.http_headers
                    )
                    content {
                      name  = http_headers.key
                      value = http_headers.value
                    }
                  }
                }
              }
            }
          }
          dynamic "ports" {
            for_each = containers.value.ports
            content {
              container_port = ports.value.container_port
              name           = ports.value.name
              protocol       = ports.value.protocol
            }
          }
          dynamic "resources" {
            for_each = containers.value.resources == null ? [] : [""]
            content {
              limits   = containers.value.resources.limits
              requests = containers.value.resources.requests
            }
          }
          dynamic "startup_probe" {
            for_each = containers.value.startup_probe == null ? [] : [""]
            content {
              failure_threshold     = containers.value.startup_probe.failure_threshold
              initial_delay_seconds = containers.value.startup_probe.initial_delay_seconds
              period_seconds        = containers.value.startup_probe.period_seconds
              timeout_seconds       = containers.value.startup_probe.timeout_seconds
              dynamic "grpc" {
                for_each = (
                  containers.value.startup_probe.action.grpc == null ? [] : [""]
                )
                content {
                  port    = containers.value.startup_probe.action.grpc.port
                  service = containers.value.startup_probe.action.grpc.service
                }
              }
              dynamic "http_get" {
                for_each = (
                  containers.value.startup_probe.action.http_get == null ? [] : [""]
                )
                content {
                  path = containers.value.startup_probe.action.http_get.path
                  dynamic "http_headers" {
                    for_each = (
                      containers.value.startup_probe.action.http_get.http_headers
                    )
                    content {
                      name  = http_headers.key
                      value = http_headers.value
                    }
                  }
                }
              }
              dynamic "tcp_socket" {
                for_each = (
                  containers.value.startup_probe.action.tcp_socket == null ? [] : [""]
                )
                content {
                  port = containers.value.startup_probe.action.tcp_socket.port
                }
              }
            }
          }
          dynamic "volume_mounts" {
            for_each = containers.value.volume_mounts
            content {
              name       = volume_mounts.key
              mount_path = volume_mounts.value
            }
          }
        }
      }
      dynamic "volumes" {
        for_each = var.volumes
        content {
          name = volumes.key
          secret {
            secret_name  = volumes.value.secret_name
            default_mode = volumes.value.default_mode
            dynamic "items" {
              for_each = volumes.value.items
              content {
                key  = items.key
                path = items.value.path
                mode = items.value.mode
              }
            }
          }
        }
      }
    }
    metadata {
      name        = local.revision_name
      annotations = local.revision_annotations
    }
  }

  metadata {
    annotations = local.annotations
  }

  dynamic "traffic" {
    for_each = var.traffic
    content {
      percent         = traffic.value.percent
      latest_revision = traffic.value.revision_name == null
      revision_name = (
        traffic.value.revision_name == null
        ? null
        : "${var.name}-${traffic.value.revision_name}"
      )
      tag = traffic.value.tag
    }
  }

  lifecycle {
    ignore_changes = [
      metadata.0.annotations
    ]
  }
}

resource "google_cloud_run_service_iam_binding" "binding" {
  for_each = var.iam
  project  = google_cloud_run_service.service.project
  location = google_cloud_run_service.service.location
  service  = google_cloud_run_service.service.name
  role     = each.key
  members  = each.value
}

resource "google_service_account" "service_account" {
  count        = var.service_account_create ? 1 : 0
  project      = var.project_id
  account_id   = "tf-cr-${var.name}"
  display_name = "Terraform Cloud Run ${var.name}."
}

resource "google_eventarc_trigger" "audit_log_triggers" {
  for_each = var.audit_log_triggers == null ? {} : {
    for trigger in var.audit_log_triggers :
    "${trigger.service_name}-${trigger.method_name}" => trigger
  }
  name     = "${local.prefix}${each.key}-audit-log-trigger"
  location = google_cloud_run_service.service.location
  project  = google_cloud_run_service.service.project
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.audit.log.v1.written"
  }
  matching_criteria {
    attribute = "serviceName"
    value     = each.value.service_name
  }
  matching_criteria {
    attribute = "methodName"
    value     = each.value.method_name
  }
  destination {
    cloud_run_service {
      service = google_cloud_run_service.service.name
      region  = google_cloud_run_service.service.location
    }
  }
}

resource "google_eventarc_trigger" "pubsub_triggers" {
  for_each = var.pubsub_triggers == null ? [] : toset(var.pubsub_triggers)
  name = (
    each.value == ""
    ? "${local.prefix}default-pubsub-trigger"
    : "${local.prefix}${each.value}-pubsub-trigger"
  )
  location = google_cloud_run_service.service.location
  project  = google_cloud_run_service.service.project
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.pubsub.topic.v1.messagePublished"
  }
  dynamic "transport" {
    for_each = each.value == null ? [] : [""]
    content {
      pubsub {
        topic = each.value
      }
    }
  }
  destination {
    cloud_run_service {
      service = google_cloud_run_service.service.name
      region  = google_cloud_run_service.service.location
    }
  }
}
