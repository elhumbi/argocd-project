variable "environment" {
  description = "Environment name"
  type        = string
}

variable "cluster_id" {
  description = "Cluster ID"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}