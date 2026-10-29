# Rename to backend.tf after running bootstrap-backend.
# Values come from backend.hcl:  terraform init -migrate-state -backend-config=backend.hcl
terraform {
  backend "s3" {}
}
