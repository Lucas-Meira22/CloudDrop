terraform {
  backend "s3" {
    bucket       = "lucas-terraform-state-137286422208"
    key          = "clouddrop/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
