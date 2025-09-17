terraform {
  backend "s3" {
    bucket  = "terraformstatesbackend"
    key     = "dream-app/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
