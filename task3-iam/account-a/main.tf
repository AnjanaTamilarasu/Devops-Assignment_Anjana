terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile_a # AWS CLI profile for Account A
}

locals {
  group1_users = ["engine", "ci"]
  group2_users = var.group2_users
}

resource "aws_iam_user" "group1" {
  for_each = toset(local.group1_users)
  name     = each.key
}

resource "aws_iam_user" "group2" {
  for_each = toset(local.group2_users)
  name     = each.key
}

# CLI-only users: access keys, NO login profile (=> no console password)
resource "aws_iam_access_key" "group1" {
  for_each = aws_iam_user.group1
  user     = each.value.name
}

# Console + CLI users: login profile AND access keys
resource "aws_iam_user_login_profile" "group2" {
  for_each                = aws_iam_user.group2
  user                    = each.value.name
  password_reset_required = true
}

resource "aws_iam_access_key" "group2" {
  for_each = aws_iam_user.group2
  user     = each.value.name
}

resource "aws_iam_group" "group1" { name = "group1" }
resource "aws_iam_group" "group2" { name = "group2" }

resource "aws_iam_group_membership" "group1" {
  name  = "group1-members"
  group = aws_iam_group.group1.name
  users = [for u in aws_iam_user.group1 : u.name]
}

resource "aws_iam_group_membership" "group2" {
  name  = "group2-members"
  group = aws_iam_group.group2.name
  users = [for u in aws_iam_user.group2 : u.name]
}

# group2: full console + CLI work (assumption: PowerUser), change own password, assume roleA
resource "aws_iam_group_policy_attachment" "group2_power" {
  group      = aws_iam_group.group2.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_group_policy_attachment" "group2_pw" {
  group      = aws_iam_group.group2.name
  policy_arn = "arn:aws:iam::aws:policy/IAMUserChangePassword"
}

resource "aws_iam_group_policy" "group2_assume_roleA" {
  name  = "assume-roleA"
  group = aws_iam_group.group2.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.roleA.arn
    }]
  })
}

# group1: may assume roleB
resource "aws_iam_group_policy" "group1_assume_roleB" {
  name  = "assume-roleB"
  group = aws_iam_group.group1.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = aws_iam_role.roleB.arn
    }]
  })
}

# ---------------- roleA : admin on everything except IAM ----------------
data "aws_iam_policy_document" "account_a_root_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_a_id}:root"] # same account: identity policies decide who
    }
  }
}

resource "aws_iam_role" "roleA" {
  name               = "roleA"
  assume_role_policy = data.aws_iam_policy_document.account_a_root_trust.json
}

resource "aws_iam_role_policy" "roleA_admin_no_iam" {
  name = "admin-except-iam"
  role = aws_iam_role.roleA.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Sid = "AllowAll", Effect = "Allow", Action = "*", Resource = "*" },
      { Sid = "DenyIAM", Effect = "Deny", Action = "iam:*", Resource = "*" }
    ]
  })
}

# ---------------- roleB : ONLY permission = assume roleC in Account B ----------------
resource "aws_iam_role" "roleB" {
  name               = "roleB"
  assume_role_policy = data.aws_iam_policy_document.account_a_root_trust.json
}

resource "aws_iam_role_policy" "roleB_assume_roleC" {
  name = "assume-roleC-in-account-b"
  role = aws_iam_role.roleB.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::${var.account_b_id}:role/roleC"
    }]
  })
}

# ---------------- Task 4: ci least-privilege policy ----------------
resource "aws_iam_policy" "ci" {
  name = "ci-pipeline-least-privilege"
  policy = templatefile("${path.module}/policies/ci-policy.json.tpl", {
    region           = var.region
    account_id       = var.account_a_id
    ecr_repo         = var.ecr_repo
    ecs_cluster      = var.ecs_cluster
    ecs_service      = var.ecs_service
    artifacts_bucket = var.artifacts_bucket
    pass_role_arns   = jsonencode(var.ecs_task_role_arns)
  })
}

resource "aws_iam_user_policy_attachment" "ci" {
  user       = aws_iam_user.group1["ci"].name
  policy_arn = aws_iam_policy.ci.arn
}
