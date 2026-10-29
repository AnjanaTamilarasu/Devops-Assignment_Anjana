output "roleA_arn" { value = aws_iam_role.roleA.arn }
output "roleB_arn" { value = aws_iam_role.roleB.arn }

output "access_keys" {
  sensitive = true
  value = merge(
    { for k, v in aws_iam_access_key.group1 : k => { id = v.id, secret = v.secret } },
    { for k, v in aws_iam_access_key.group2 : k => { id = v.id, secret = v.secret } }
  )
}

output "console_passwords" {
  sensitive = true
  value     = { for k, v in aws_iam_user_login_profile.group2 : k => v.password }
}
