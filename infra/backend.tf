terraform {
  backend "s3" {
    bucket       = "tfstate-workload-migration-509399596610"
    key          = "poc/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
