output "kubeconfig_path" {
  description = "Path to the generated kubeconfig for this cluster"
  value       = kind_cluster.securekube.kubeconfig_path
}

output "cluster_name" {
  description = "Name of the provisioned kind cluster"
  value       = kind_cluster.securekube.name
}

output "endpoint" {
  description = "API server endpoint"
  value       = kind_cluster.securekube.endpoint
  sensitive   = true
}
