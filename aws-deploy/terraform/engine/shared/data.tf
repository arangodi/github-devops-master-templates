#data "aws_cloudformation_stack" "network" {
#  name = local.config.globals.network.stack_name
#}
data "aws_cloudformation_stack" "network" {
  count = try(local.config.globals.network.stack_name, null) != null ? 1 : 0
  name  = local.config.globals.network.stack_name
}