terraform {
  required_version = ">= 1.5.0"

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ------------------------------------------------------------------
# Cluster provisioning via the real `kind` CLI, driven by a static
# YAML config (kind-config.yaml). We moved away from the tehcyx/kind
# Terraform provider's inline `kind_config` block: it repeatedly failed
# to complete multi-node worker joins when combined with custom
# kubeadm_config_patches (workers never even attempted `kubeadm join`
# after several minutes). Shelling out to `kind` directly is the same
# underlying tool, just without that provider's translation layer.
# ------------------------------------------------------------------
resource "null_resource" "kind_cluster" {
  triggers = {
    cluster_name = var.cluster_name
    config_hash  = filesha256("${path.module}/kind-config.yaml")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      cd "${path.module}"
      if kind get clusters | grep -qx "${var.cluster_name}"; then
        echo "Cluster '${var.cluster_name}' already exists, skipping creation"
      else
        kind create cluster --name ${var.cluster_name} --config kind-config.yaml --wait 120s
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name ${self.triggers.cluster_name} || true"
  }
}

# Install Calico when default CNI is disabled, since kindnet does not
# enforce NetworkPolicy (required for CIS 5.3.2 / zero-trust default-deny)
resource "null_resource" "install_calico" {
  count = var.enable_network_policy_cni ? 1 : 0

  depends_on = [null_resource.kind_cluster]

  provisioner "local-exec" {
    command = "kubectl --context kind-${var.cluster_name} apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml"
  }
}

# Wait for all nodes to report Ready before Terraform hands control
# back to the Makefile — otherwise `make policies` / `make gatekeeper`
# could run against a cluster that still can't schedule pods.
resource "null_resource" "wait_for_nodes_ready" {
  depends_on = [null_resource.install_calico, null_resource.kind_cluster]

  provisioner "local-exec" {
    command = "kubectl --context kind-${var.cluster_name} wait --for=condition=Ready nodes --all --timeout=180s"
  }
}
