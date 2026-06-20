locals {
  sqs_by_name = merge(module.sqs_dlq, module.sqs_queues)

  sqs_sns_source_arns = {
    for qname, q in local.sqs_sns_policy_queues : qname => compact(concat(
      try(q.allow_sns_publish_from_topic, null) != null ? [module.sns_topics[q.allow_sns_publish_from_topic].arn] : [],
      [for topic_name in try(q.allow_sns_publish_from_topics, []) : module.sns_topics[topic_name].arn],
      try(q.allow_sns_publish_from_topic_arns, [])
    ))
  }

  subscription_filter_policy_inputs = merge([
    for topic in local.sns_topics : {
      for idx, sub in try(topic.subscriptions, []) :
      "${topic.name}-${idx}" => sub
    }
  ]...)

  encode_filter_policy = {
    for key, value in merge(local.subscription_filter_policy_inputs, local.external_sns_subscriptions) : key => (
      try(value.filter_policy, null) == null ? null : (
        can(jsondecode(value.filter_policy)) ? value.filter_policy : jsonencode(value.filter_policy)
      )
    )
  }
}

#################################################
# MESSAGING / SQS — DLQ (sin redrive)
#################################################
module "sqs_dlq" {
  for_each = local.sqs_dlq_queues

  source = "../../../modules/catalog/messaging/sqs"

  name         = each.value.name
  project_name = var.project_name
  environment  = var.environment
  account      = var.account

  fifo                              = try(each.value.fifo, false)
  content_based_deduplication       = try(each.value.content_based_deduplication, false)
  visibility_timeout                = try(each.value.visibility_timeout, 30)
  message_retention_seconds         = try(each.value.message_retention_seconds, 345600)
  delay_seconds                     = try(each.value.delay_seconds, 0)
  maximum_message_size              = try(each.value.maximum_message_size, 262144)
  receive_message_wait_time_seconds = try(each.value.receive_message_wait_time_seconds, 0)
  dead_letter_queue                 = null

  tags = merge(local.project_tags, try(each.value.tags, {}))
}

#################################################
# MESSAGING / SQS — colas principales (con redrive a DLQ)
#################################################
module "sqs_queues" {
  for_each = local.sqs_primary_queues

  source = "../../../modules/catalog/messaging/sqs"

  name         = each.value.name
  project_name = var.project_name
  environment   = var.environment
  account       = var.account

  fifo                              = try(each.value.fifo, false)
  content_based_deduplication       = try(each.value.content_based_deduplication, false)
  visibility_timeout                = try(each.value.visibility_timeout, 30)
  message_retention_seconds         = try(each.value.message_retention_seconds, 345600)
  delay_seconds                     = try(each.value.delay_seconds, 0)
  maximum_message_size              = try(each.value.maximum_message_size, 262144)
  receive_message_wait_time_seconds = try(each.value.receive_message_wait_time_seconds, 0)

  dead_letter_queue = {
    target_arn = coalesce(
      try(each.value.dead_letter_queue.target_arn, null),
      module.sqs_dlq[each.value.dead_letter_queue.target_name].arn
    )
    max_receive_count = each.value.dead_letter_queue.max_receive_count
  }

  tags = merge(local.project_tags, try(each.value.tags, {}))
}

#################################################
# MESSAGING / SQS — política para publicación desde SNS
#################################################
data "aws_iam_policy_document" "sqs_sns_publish" {
  for_each = local.sqs_sns_policy_queues

  dynamic "statement" {
    for_each = length(local.sqs_sns_source_arns[each.key]) > 0 ? [1] : []

    content {
      sid    = "AllowSNSToSendMessage"
      effect = "Allow"

      principals {
        type        = "Service"
        identifiers = ["sns.amazonaws.com"]
      }

      actions   = ["sqs:SendMessage"]
      resources = [local.sqs_by_name[each.key].arn]

      condition {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = local.sqs_sns_source_arns[each.key]
      }
    }
  }

  dynamic "statement" {
    for_each = length(try(each.value.cross_account_principals, [])) > 0 ? [1] : []

    content {
      sid    = "AllowCrossAccountSendMessage"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = each.value.cross_account_principals
      }

      actions   = ["sqs:SendMessage"]
      resources = [local.sqs_by_name[each.key].arn]
    }
  }
}

resource "aws_sqs_queue_policy" "sns_publish" {
  for_each = data.aws_iam_policy_document.sqs_sns_publish

  queue_url = local.sqs_by_name[each.key].id
  policy    = each.value.json
}

#################################################
# MESSAGING / SQS — suscripciones a topics SNS externos
#################################################
resource "aws_sns_topic_subscription" "external" {
  for_each = local.external_sns_subscriptions

  topic_arn            = each.value.topic_arn
  protocol             = "sqs"
  endpoint             = local.sqs_by_name[each.value.queue_name].arn
  filter_policy        = local.encode_filter_policy[each.key]
  filter_policy_scope  = try(each.value.filter_policy, null) != null ? coalesce(try(each.value.filter_policy_scope, null), "MessageAttributes") : null
  raw_message_delivery = try(each.value.raw_message_delivery, false)
}

#################################################
# MESSAGING / SNS
#################################################
module "sns_topics" {
  for_each = { for t in local.sns_topics : t.name => t }

  source = "../../../modules/catalog/messaging/sns"

  name         = each.value.name
  project_name = var.project_name
  environment  = var.environment
  account      = var.account

  fifo                        = try(each.value.fifo, false)
  content_based_deduplication = try(each.value.content_based_deduplication, false)
  kms_master_key_id           = try(each.value.kms_master_key_id, null)
  policy_statements           = try(each.value.policy_statements, [])
  subscriptions = [
    for idx, sub in try(each.value.subscriptions, []) : {
      protocol             = sub.protocol
      endpoint             = sub.protocol == "sqs" && try(sub.queue, null) != null ? local.sqs_by_name[sub.queue].arn : sub.endpoint
      filter_policy        = local.encode_filter_policy["${each.key}-${idx}"]
      filter_policy_scope  = try(sub.filter_policy_scope, null)
      raw_message_delivery = try(sub.raw_message_delivery, false)
      redrive_policy       = try(sub.redrive_policy, null)
    }
  ]

  tags = merge(local.project_tags, try(each.value.tags, {}))
}
