data "aws_region" "current" {}

locals {
  queue_name_base = lower("sqs-${var.project_name}-${var.name}")
  queue_name      = var.fifo ? "${local.queue_name_base}.fifo" : local.queue_name_base

  common_tags = merge({
    Name         = local.queue_name
    project_name = var.project_name
    module       = "catalog/messaging/sqs"
  }, var.tags)
}

resource "aws_sqs_queue" "this" {
  name                        = local.queue_name
  fifo_queue                  = var.fifo
  delay_seconds               = var.delay_seconds
  max_message_size            = var.maximum_message_size
  message_retention_seconds   = var.message_retention_seconds
  receive_wait_time_seconds   = var.receive_message_wait_time_seconds
  visibility_timeout_seconds  = var.visibility_timeout
  content_based_deduplication = var.fifo ? var.content_based_deduplication : null

  tags = local.common_tags
}

resource "aws_sqs_queue_redrive_policy" "this" {
  count = var.dead_letter_queue != null ? 1 : 0

  queue_url = aws_sqs_queue.this.url
  redrive_policy = jsonencode({
    deadLetterTargetArn = var.dead_letter_queue.target_arn
    maxReceiveCount     = var.dead_letter_queue.max_receive_count
  })
}
