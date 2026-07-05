variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "securekube"
}

variable "enable_network_policy_cni" {
  description = "Install Calico so NetworkPolicy (default-deny) is actually enforced. kind-config.yaml already disables the default CNI to match; toggling this only controls whether Calico gets installed."
  type        = bool
  default     = true
}
