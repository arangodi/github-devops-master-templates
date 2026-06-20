output "sns_topics" {
  description = "Map de topics SNS — key es el nombre lógico declarado en config.yml"
  value = {
    for k, m in module.sns_topics : k => {
      name = m.name
      arn  = m.arn
      id   = m.id
    }
  }
}

output "sqs_queues" {
  description = "Map de colas SQS — key es el nombre lógico declarado en config.yml"
  value = {
    for k, m in local.sqs_by_name : k => {
      id   = m.id
      arn  = m.arn
      name = m.name
    }
  }
}
