account_a_id = "792355934795"
account_b_id = "886550193259"
profile_a    = "default"

ecr_repo         = "my-app"
ecs_cluster      = "my-cluster"
ecs_service      = "my-service"
artifacts_bucket = "my-build-artifacts-bucket"
ecs_task_role_arns = [
  "arn:aws:iam::792355934795:role/my-app-task-role",
  "arn:aws:iam::792355934795:role/my-app-task-execution-role",
]
