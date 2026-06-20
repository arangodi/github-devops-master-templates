data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "btg.${var.environment}.${var.account}.terraform"
    key    = "${var.account}/${var.environment}/${var.project_name}/shared/terraform.tfstate"
    region = var.aws_region
  }
  defaults = {
    api_gw_cloudwatch_role_arn = null
  }
}

#data "terraform_remote_state" "security" {
#  backend = "s3"
#  config = {
#    bucket = "btg.${var.environment}.${var.account}.terraform"
#    key    = "${var.account}/${var.environment}/${var.project_name}/security/terraform.tfstate"
#    region = var.aws_region
#  }
#}

data "aws_acm_certificate" "this" {
  for_each = {
    for a in coalesce(try(local.catalog.networking.elbs, null), []) : a.name => a
    if try(a.certificate_arn, null) == null
    && try(a.create, true) == true
    && try(a.load_balancer_type, "application") == "application"
    && try(a.port, 443) == 443
  }

  domain      = "${each.value.name}${replace(var.environment, ".", "-")}.btgpactual.com.co"
  statuses    = ["ISSUED"]
  most_recent = true
}