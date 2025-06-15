variable "environment" {
  description = "Environment name"
  type        = string
}

variable "secrets" {
  description = "Secrets configuration"
  type = object({
    git_token = optional(string)
    docker_registry = optional(object({
      username = string
      password = string
    }))
  })
  default = {}
  sensitive = true
}