locals {
  ############################################
  # LECTURA ARCHIVO DE CONFIGURACION
  ############################################
  config  = yamldecode(file(var.config_file))
  catalog = try(local.config.catalog, {})

  ############################################
  # TAGS DESDE tags.yml
  ############################################
  project_tags = try(
    {
      for tag in yamldecode(file("${dirname(var.config_file)}/tags.yml")).variables :
      tag.name => tag.value
    },
    {}
  )

  ############################################
  # MESSAGING / SQS
  ############################################
  sqs_queues = try(local.catalog.messaging.sqs_queues, [])

  # DLQs primero (sin redrive); colas principales después (referencian DLQ).
  # Evita ciclo al resolver dead_letter_queue.target_name en el mismo for_each.
  sqs_dlq_queues = {
    for q in local.sqs_queues : q.name => q
    if try(q.dead_letter_queue, null) == null
  }

  sqs_primary_queues = {
    for q in local.sqs_queues : q.name => q
    if try(q.dead_letter_queue, null) != null
  }

  ############################################
  # MESSAGING / SNS
  ############################################
  sns_topics = try(local.catalog.messaging.sns_topics, [])

  ############################################
  # MESSAGING / SQS — políticas SNS y suscripciones externas
  ############################################
  sqs_sns_policy_queues = {
    for q in local.sqs_queues : q.name => q
    if(
      try(q.allow_sns_publish_from_topic, null) != null ||
      length(try(q.allow_sns_publish_from_topics, [])) > 0 ||
      length(try(q.allow_sns_publish_from_topic_arns, [])) > 0 ||
      length(try(q.cross_account_principals, [])) > 0
    )
  }

  external_sns_subscriptions = merge([
    for q in local.sqs_queues : {
      for idx, sub in try(q.external_subscriptions, []) :
      "${q.name}-${idx}" => merge(sub, { queue_name = q.name })
    }
  ]...)
}
