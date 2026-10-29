See NOTES.md for the written answers. Order in which things were run:
1. task1-2-ec2           (Task 1, local state)
2. bootstrap-backend     (creates the S3 bucket and DynamoDB lock table)
3. task1-2-ec2           (Task 2, state migrated to S3 using backend.hcl)
4. task3-iam/account-a   then task3-iam/account-b  (Tasks 3 and 4)
5. task5-fix             (reference only, not applied)
