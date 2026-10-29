# Runs in ACCOUNT B
data "aws_iam_policy_document" "roleC_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      # FIX 1: roleB is a ROLE, not a user  ->  :role/roleB  (was :user/roleB)
      identifiers = ["arn:aws:iam::792355934795:role/roleB"]
    }
  }
}

resource "aws_iam_role" "roleC" {
  name               = "roleC"
  assume_role_policy = data.aws_iam_policy_document.roleC_trust.json
}

resource "aws_iam_role_policy" "roleC_s3" {
  name = "roleC-s3-access"
  role = aws_iam_role.roleC.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "s3:*"
      # FIX 2: scope to the one bucket (bucket ARN for bucket-level actions, /* for objects)
      Resource = [
        "arn:aws:s3:::my-target-bucket",
        "arn:aws:s3:::my-target-bucket/*"
      ]
    }]
  })
}
