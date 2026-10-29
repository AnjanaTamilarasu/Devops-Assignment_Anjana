variable "region" {
  type    = string
  default = "ap-south-1"
}
variable "profile_b" { type = string }
variable "account_a_id" { type = string }
variable "bucket_name" {
  description = "Globally unique bucket name roleC gets full access to"
  type        = string
}
