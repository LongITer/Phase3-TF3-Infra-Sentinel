# Remote state backend - values are NOT hardcoded here on purpose.
# The S3 bucket + DynamoDB lock table must exist BEFORE `terraform init`
# (Terraform can't create the backend it's about to use). Bootstrap once
# with the AWS CLI commands in README.md, then run:
#
#   terraform init -backend-config=backend.hcl
#
# backend.hcl is intentionally not committed with real values by default -
# copy backend.hcl.example -> backend.hcl and fill in the real bucket/table
# names for your account (they aren't secret, just kept out of version
# control so each environment/account can point at its own state).
terraform {
  backend "s3" {}
}
