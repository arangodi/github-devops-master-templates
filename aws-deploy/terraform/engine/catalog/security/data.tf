data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "btg.${var.environment}.${var.account}.terraform"
    key    = "${var.account}/${var.environment}/${var.project_name}/shared/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "compute" {
  backend = "s3"
  config = {
    bucket = "btg.${var.environment}.${var.account}.terraform"
    key    = "${var.account}/${var.environment}/${var.project_name}/compute/terraform.tfstate"
    region = var.aws_region
  }
  defaults = {
    ecs_services   = {}
    ec2_instances  = {}
    eks_clusters   = {}
  }
}
