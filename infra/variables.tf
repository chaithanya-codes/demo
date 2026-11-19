variable "aws_region" {
  description = "AWS region containing the EKS cluster."
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "Existing EKS cluster Jenkins deploys to."
  type        = string
  default     = "k8s-training-dev"
}

variable "jenkins_ui_cidr" {
  description = "Your public IPv4 address with /32; only this address can access Jenkins on port 8080."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.jenkins_ui_cidr)) && endswith(var.jenkins_ui_cidr, "/32")
    error_message = "Set jenkins_ui_cidr to one IPv4 address with a /32 mask, for example 203.0.113.10/32."
  }
}
