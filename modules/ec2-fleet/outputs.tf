locals {
  all_instances = merge(aws_instance.this, aws_instance.protected)
}

output "instance_ids" {
  description = "instance name => instance ID"
  value       = { for name, i in local.all_instances : name => i.id }
}

output "private_ips" {
  description = "instance name => private IP"
  value       = { for name, i in local.all_instances : name => i.private_ip }
}
