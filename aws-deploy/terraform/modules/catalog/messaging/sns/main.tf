locals {
  topic_base_name = lower("sns-${var.project_name}-${var.name}")
  topic_name      = var.fifo ? "${local.topic_base_name}.fifo" : local.topic_base_name

  common_tags = merge({
    Name         = local.topic_name
    project_name = var.project_name
    module       = "catalog/messaging/sns"
  }, var.tags)
}

resource "aws_sns_topic" "this" {
  name                        = local.topic_name
  fifo_topic                  = var.fifo
  kms_master_key_id           = var.kms_master_key_id
  content_based_deduplication = var.fifo ? var.content_based_deduplication : null

  tags = local.common_tags
}

data "aws_iam_policy_document" "this" {
  count = length(var.policy_statements) > 0 ? 1 : 0

  dynamic "statement" {
    for_each = var.policy_statements
    content {
      sid         = try(statement.value.sid, null)
      effect      = statement.value.effect
      actions     = statement.value.actions
      not_actions = try(statement.value.not_actions, null)
      resources = coalesce(
        try(statement.value.resources, null),
        [aws_sns_topic.this.arn]
      )

      dynamic "principals" {
        for_each = statement.value.principals
        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = try(statement.value.conditions, [])
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  count = length(var.policy_statements) > 0 ? 1 : 0

  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.this[0].json
}

resource "aws_sns_topic_subscription" "this" {
  for_each = {
    for i, sub in var.subscriptions : tostring(i) => sub
  }

  topic_arn            = aws_sns_topic.this.arn
  protocol             = each.value.protocol
  endpoint             = each.value.endpoint
  filter_policy        = each.value.filter_policy
  filter_policy_scope  = each.value.filter_policy != null ? coalesce(each.value.filter_policy_scope, "MessageAttributes") : null
  raw_message_delivery = each.value.raw_message_delivery
  redrive_policy       = each.value.redrive_policy
}
