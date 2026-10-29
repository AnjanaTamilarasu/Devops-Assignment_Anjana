# NOTES

## Task 1 – Which instance I protected and why
All five instances are created from one input variable, a map called `instances`. Each entry has its own instance type,
root volume type, volume size and key pair. The module loops over that map, so there are no five hard-coded blocks.

One small catch: `prevent_destroy` has to be a fixed value in Terraform, so it can't change per instance inside a loop.
So I split the map into two groups, instances marked `protected = true` and the rest. There are two `aws_instance` blocks
with the same settings, and only the protected one has `lifecycle { prevent_destroy = true }`. Both are still driven by the same variable.

The protected instance is `db-1`. It's the one with the io1 volume, so I treat it as the database server. It holds
data, and it's the hardest and most expensive one to rebuild. If someone runs `terraform destroy` by mistake, or changes
something that forces a replacement, the data would be lost. The web, app and cache servers are stateless and can be recreated any time.
Because of this, Terraform will refuse to destroy `db-1` until the lifecycle block is removed on purpose.

## Task 2 – Local state vs remote state with locking

What happens today with local state:

every person gets their own `terraform.tfstate` file on their own machine, and
there is no locking. If two people run `apply` at the same time, each one is working from a different picture of what
exists. The result could be duplicate resources, or resources that one person's state doesn't know about. And if they share
the state file through git or a shared folder, the last person to save overwrites the other, and the state can get corrupted
or lose track of things.

How the backend fixes it: the state is stored in one S3 bucket that everyone uses, with versioning and encryption turned on.
Before Terraform changes anything, it writes a lock entry in a DynamoDB table (the key is `LockID`), and that write only
succeeds if no lock exists yet. So only one person can hold the lock. The second person's `apply` fails with
"Error acquiring the state lock" and shows who holds it. When the first run finishes, the lock is released. S3 versioning also means I can go back to an older state if something goes wrong.

## Task 3 – Questions

1. Would I really give `engine` and `ci` IAM users with access keys in production?
No, I would avoid it. Access keys don't expire, so if one leaks through a git repo, a log file or a laptop, someone
can use it until we notice and delete it. They're also hard to rotate and hard to trace back to a person or job.
I'd do this instead:
- For `ci`: use OIDC federation. For example, GitHub Actions or GitLab can assume an IAM role directly and get temporary
  credentials for each run, and I can lock the trust policy to one repo and branch. No stored keys at all.
- For `engine` (an application or service): attach an IAM role to where it runs, like an EC2 instance profile or an
  ECS task role. The credentials are temporary and rotate automatically.
- For people: IAM Identity Center (SSO) with MFA.

If I really had no choice, say for an old tool that can't use roles, I'd give the user minimum permissions, keep the keys in
Secrets Manager, rotate them regularly, restrict them by source IP, and watch their usage in CloudTrail.

2. In roleC's trust policy, why does it matter whether I trust the whole Account A root or only roleB's ARN?
If I trust the Account A root, I'm saying "anyone in Account A can assume roleC, as long as Account A gives them permission".
That means Account A's admins decide who can reach my role in Account B, and anyone who can edit IAM policies in
Account A could give themselves access. In our own setup, roleA (allows everything except IAM) and the group2 users
(PowerUserAccess) are allowed to call `sts:AssumeRole`, so they could assume roleC too, which we never intended.

If I trust only `role/roleB`, then only that one role can get in, no matter what other permissions exist in Account A.
The trust policy itself enforces least privilege. There's also a small bonus: IAM remembers the role's internal ID, so if
someone deletes roleB and creates a new role with the same name, it does not automatically get access.
Cross-account access needs both sides, though. Account B's trust policy must allow roleB, and roleB must also have a policy in
Account A allowing `sts:AssumeRole` on roleC, which we've done.


One assumption:* the assignment says group2 has "full console + CLI access" without saying exactly what that means.
I gave group2 PowerUserAccess, the ability to change their own password, and permission to assume roleA.

## Task 4 – What I left out of the `ci` policy, and why
I wrote the policy so `ci` can do only three jobs: push an image to one ECR repo, deploy to one ECS service, and read one S3 bucket.
Here is what I deliberately did not include:
- ECR: no `ecr:*`, and nothing like create repo, delete repo, delete images or change repo policy. A pipeline only needs
  to upload image layers and the image manifest. I also left out the pull permissions, because pushing doesn't need them.
  If the pipeline has to pull base images from the same repo, I'd add them then.
- ECS: no create service, delete service, run task or stop task. The pipeline only updates one existing service, so
  `UpdateService` and `DescribeServices` are limited to that service's ARN.
- `iam:PassRole`: I included this because registering a task definition with roles won't work without it. But I limited it to the
  specific task role and execution role, and only when they are passed to `ecs-tasks.amazonaws.com`. A broad PassRole would
  let someone escalate their privileges.
- S3: read only. That means `GetObject` (and `GetObjectVersion`) on the objects and `ListBucket` on that one bucket.
  No `PutObject`, no `DeleteObject`, nothing on other buckets.
- Everything else: no IAM, STS, EC2, CloudWatch Logs or KMS permissions. If the bucket is encrypted with a customer key,
  I would add `kms:Decrypt` for that one key only.

A few actions still use `*` as the resource, because AWS doesn't support narrowing them down:
`ecr:GetAuthorizationToken`, `ecs:RegisterTaskDefinition` and `ecs:DescribeTaskDefinition`.
That's the only wildcard in the policy.

## Task 5 – Why the snippet was failing
There were two problems.

1. The trust policy. The principal was written as `arn:aws:iam::000000000000:user/roleB`. But roleB is an IAM *role*,
not a user, so the ARN should end in `role/roleB`. There's no user called roleB, so IAM can't find that principal and rejects
the trust policy when creating the role (an "invalid principal" error). Even if a user with that name existed, a role session is a
different kind of principal, so it wouldn't match and the assume-role call would be denied.
The fix is to use `arn:aws:iam::000000000000:role/roleB`.

2. The permissions policy. It allowed `s3:*` on `Resource = "*"`. That gives roleC every S3 action on every bucket in
Account B, but the requirement was access to one named bucket only. The fix is to list just that bucket: the bucket ARN
(for actions on the bucket itself, like ListBucket) and `bucket-arn/*` (for actions on the objects inside, like GetObject and PutObject).
