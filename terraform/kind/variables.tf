variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "securekube"
}

variable "control_plane_count" {
  description = "Number of control-plane nodes"
  type        = number
  default     = 1
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "enable_network_policy_cni" {
  description = "Disable kindnet and install Calico so NetworkPolicy (default-deny) is actually enforced"
  type        = bool
  default     = true
}
