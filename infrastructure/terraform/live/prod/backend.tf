terraform {
  backend "s3" {
    bucket         = "platform-terraform-state"
    key            = "live/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "platform-terraform-locks"
  }
}
