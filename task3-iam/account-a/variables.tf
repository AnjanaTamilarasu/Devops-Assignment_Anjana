variable "region" {
  type    = string
  default = "ap-south-1"
}
variable "profile_a" {
  description = "AWS CLI profile for Account A"
  type        = string
  default     = "default"
}
variable "account_a_id" { type = string }
variable "account_b_id" { type = string }
variable "group2_users" {
  type    = list(string)
  default = ["user1", "user2"]
}

# Task 4 inputs
variable "ecr_repo" {
  type    = string
  default = "my-app"
}
variable "ecs_cluster" {
  type    = string
  default = "my-cluster"
}
variable "ecs_service" {
  type    = string
  default = "my-service"
}
variable "artifacts_bucket" {
  type    = string
  default = "my-build-artifacts-bucket"
}
variable "ecs_task_role_arns" {
  description = "Task role + execution role the pipeline may pass to ECS (at least one)"
  type        = list(string)
}
