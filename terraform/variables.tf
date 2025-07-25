variable "region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "3-tier-cluster"
}

variable "db_password" {
  description = "RDS PostgreSQL password"
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for Route53"
  default     = "example.com"
}
