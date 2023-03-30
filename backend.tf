terraform {
  backend "s3" {
    bucket = "terraform-tfstate-akshay"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
