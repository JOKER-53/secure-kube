terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

# ------------------------------------------------------------------
# Cluster provisioning
# CIS control refs: 1.1.x (file perms handled by kind image defaults),
# 1.2.x (API server flags below)
# ------------------------------------------------------------------
resource "kind_cluster" "securekube" {
  name           = var.cluster_name
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # CIS 1.2.x — enable audit logging, disable anonymous auth,
    # disable insecure ports, enforce strong admission controllers
    dynamic "node" {
      for_each = range(var.control_plane_count)
      content {
        role = "control-plane"

        kubeadm_config_patches = [
          yamlencode({
            kind = "ClusterConfiguration"
            apiServer = {
              extraArgs = {
                "audit-log-path"            = "/var/log/kubernetes/audit.log"
                "audit-log-maxage"          = "30"
                "audit-log-maxbackup"       = "10"
                "audit-log-maxsize"         = "100"
                "audit-policy-file"         = "/etc/kubernetes/audit-policy.yaml"
                "anonymous-auth"            = "false"
                "profiling"                 = "false"
                "enable-admission-plugins"  = "NodeRestriction,PodSecurity,EventRateLimit"
              }
              extraVolumes = [
                {
                  name      = "audit-policy"
                  hostPath  = "/etc/kubernetes/audit-policy.yaml"
                  mountPath = "/etc/kubernetes/audit-policy.yaml"
                  readOnly  = true
                  pathType  = "File"
                },
                {
                  name      = "audit-logs"
                  hostPath  = "/var/log/kubernetes"
                  mountPath = "/var/log/kubernetes"
                  readOnly  = false
                  pathType  = "DirectoryOrCreate"
                }
              ]
            }
            controllerManager = {
              extraArgs = {
                "profiling"                    = "false"
                "terminated-pod-gc-threshold"  = "50"
              }
            }
            scheduler = {
              extraArgs = {
                "profiling" = "false"
              }
            }
          })
        ]

        extra_mounts {
          host_path      = abspath("${path.module}/audit-policy.yaml")
          container_path = "/etc/kubernetes/audit-policy.yaml"
        }
      }
    }

    dynamic "node" {
      for_each = range(var.worker_count)
      content {
        role = "worker"
      }
    }

    # CIS 5.3.2 — default-deny CNI capable networking (kindnet swapped for calico if needed)
    networking {
      disable_default_cni = var.enable_network_policy_cni
      pod_subnet          = "10.244.0.0/16"
      service_subnet      = "10.96.0.0/12"
    }
  }
}

# Install Calico when default CNI is disabled, since kindnet does not
# enforce NetworkPolicy (required for CIS 5.3.2 / zero-trust default-deny)
resource "null_resource" "install_calico" {
  count = var.enable_network_policy_cni ? 1 : 0

  depends_on = [kind_cluster.securekube]

  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${kind_cluster.securekube.kubeconfig_path} apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml"
  }
}
