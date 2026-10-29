variable "region" {
  type    = string
  default = "ap-south-1"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "owner" {
  type    = string
  default = "Owner_Anjana"
}
variable "instances" {
  type = map(object({
    instance_type = string
    volume_type   = string
    volume_size   = number
    key_name      = string
    iops          = optional(number)
    protected     = optional(bool, false)
  }))
}
