# S3 for remote backend
terraform {
  backend "s3" {
    bucket         = "autoheal-terraform-remotebackend"
    key            = "autoheal-cloud/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "autoheal-terraform-locks"
    encrypt        = true
  }
}


# Primary AWS region provider
provider "aws" {
  region = var.region_primary
}

# Secondary AWS region provider
provider "aws" {
  alias  = "secondary"
  region = var.region_secondary
}
