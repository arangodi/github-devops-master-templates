data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "btg.${var.environment}.${var.account}.terraform"
    key    = "${var.account}/${var.environment}/${var.project_name}/shared/terraform.tfstate"
    region = var.aws_region
  }
}

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "btg.${var.environment}.${var.account}.terraform"
    key    = "${var.account}/${var.environment}/${var.project_name}/networking/terraform.tfstate"
    region = var.aws_region
  }
  defaults = {
    elbs       = {}
    namespaces = {}
    eni_interfaces = {}
    api-gateway = {}
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "btg.${var.environment}.${var.account}.terraform"
    key    = "${var.account}/${var.environment}/${var.project_name}/security/terraform.tfstate"
    region = var.aws_region
  }
  defaults = {
    secrets = {}
  }
}

data "terraform_remote_state" "storage" {
  backend = "s3"
  config = {
    bucket = "btg.${var.environment}.${var.account}.terraform"
    key    = "${var.account}/${var.environment}/${var.project_name}/storage/terraform.tfstate"
    region = var.aws_region
  }
  defaults = {
    s3_buckets             = {}
    efs_filesystems        = {}
    efs_filesystem_ids     = {}
    efs_access_point_ids   = {}
    efs_security_group_ids = {}
  }
}