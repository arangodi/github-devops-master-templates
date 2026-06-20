data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "btg.${var.environment}.${var.account}.terraform"
    key    = "${var.account}/${var.environment}/${var.project_name}/shared/terraform.tfstate"
    region = var.aws_region
  }
}