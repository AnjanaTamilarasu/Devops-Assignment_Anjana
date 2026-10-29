locals {
  protected_instances = { for k, v in var.instances : k => v if v.protected }
  regular_instances   = { for k, v in var.instances : k => v if !v.protected }
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ssm_parameter" "al2023_arm" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

locals {
  # true for Graviton types such as t4g.*, m7g.*, c7g.*
  is_arm = { for k, v in var.instances : k => can(regex("^[a-z]+[0-9]+g[a-z]*\\.", v.instance_type)) }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------- one key pair per instance ----------
resource "tls_private_key" "this" {
  for_each  = var.instances
  algorithm = "ED25519"
}

resource "aws_key_pair" "this" {
  for_each   = var.instances
  key_name   = each.value.key_name
  public_key = tls_private_key.this[each.key].public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  for_each             = var.instances
  content              = tls_private_key.this[each.key].private_key_openssh
  filename             = "${var.key_output_dir}/${each.value.key_name}.pem"
  file_permission      = "0400"
  directory_permission = "0700"
}

# ---------- regular instances ----------
resource "aws_instance" "this" {
  for_each = local.regular_instances

  ami = nonsensitive(local.is_arm[each.key] ? data.aws_ssm_parameter.al2023_arm.value : data.aws_ssm_parameter.al2023.value)
  instance_type = each.value.instance_type
  key_name      = aws_key_pair.this[each.key].key_name
  subnet_id     = sort(data.aws_subnets.default.ids)[0]

  root_block_device {
    volume_type           = each.value.volume_type
    volume_size           = each.value.volume_size
    iops                  = contains(["io1", "io2"], each.value.volume_type) ? each.value.iops : null
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }
}

# ---------- protected instance(s): same config + lifecycle ----------
# prevent_destroy must be a literal, so it can't be set per-key in the block above.
resource "aws_instance" "protected" {
  for_each = local.protected_instances

  ami = nonsensitive(local.is_arm[each.key] ? data.aws_ssm_parameter.al2023_arm.value : data.aws_ssm_parameter.al2023.value)
  instance_type = each.value.instance_type
  key_name      = aws_key_pair.this[each.key].key_name
  subnet_id     = sort(data.aws_subnets.default.ids)[0]

  root_block_device {
    volume_type           = each.value.volume_type
    volume_size           = each.value.volume_size
    iops                  = contains(["io1", "io2"], each.value.volume_type) ? each.value.iops : null
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = each.key
    Environment = var.environment
    Owner       = var.owner
  }

  lifecycle {
    prevent_destroy = true
  }
}
