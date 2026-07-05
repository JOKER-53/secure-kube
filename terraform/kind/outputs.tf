output "cluster_name" {
  description = "Name of the provisioned kind cluster"
  value       = var.cluster_name
}

output "kubectl_context" {
  description = "kubectl context to use for this cluster (kind auto-registers this in ~/.kube/config)"
  value       = "kind-${var.cluster_name}"
}
