variable "instances" {
  description = "Single input that drives every instance. Key = instance name."
  type = map(object({
    instance_type = string
    volume_type   = string           # gp3, gp2, io1, io2, standard ...
    volume_size   = number           # GiB
    key_name      = string           # key pair name (module creates it)
    iops          = optional(number) # required for io1/io2
    protected     = optional(bool, false) # true => prevent_destroy
  }))

  validation {
    condition = alltrue([
      for k, v in var.instances :
      contains(["io1", "io2"], v.volume_type) ? v.iops != null : true
    ])
    error_message = "io1/io2 volumes must set iops."
  }
}

variable "environment" { type = string }
variable "owner" { type = string }

variable "key_output_dir" {
  description = "Local folder where generated private keys are written."
  type        = string
  default     = "./keys"
}
