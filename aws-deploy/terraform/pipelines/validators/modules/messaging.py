import re
import json
from typing import Optional, List, Any
from enum import Enum
from pydantic import field_validator, model_validator, Field
from validators.base import StrictModel, validate_arn_or_variable


#################################################
# ENUMS
#################################################

class SNSProtocolEnum(str, Enum):
    sqs        = "sqs"
    lambda_    = "lambda"
    http       = "http"
    https      = "https"
    email      = "email"
    email_json = "email-json"
    sms        = "sms"
    application = "application"
    firehose   = "firehose"


class FilterPolicyScopeEnum(str, Enum):
    MESSAGE_ATTRIBUTES = "MessageAttributes"
    MESSAGE_BODY       = "MessageBody"


#################################################
# SQS — Dead Letter Queue reference
#################################################

class DeadLetterQueue(StrictModel):
    target_arn:        Optional[str] = None   
    target_name:       Optional[str] = None   
    max_receive_count: int           = Field(default=3, ge=1, le=1000)

    @field_validator('target_arn')
    @classmethod
    def validate_target_arn(cls, v):
        if v is None:
            return v
        return validate_arn_or_variable(v, service_hint="SQS DLQ")

    @model_validator(mode='after')
    def validate_exactly_one_target(self):
        if self.target_arn and self.target_name:
            raise ValueError(
                "Declara 'target_arn' O 'target_name', no ambos"
            )
        if not self.target_arn and not self.target_name:
            raise ValueError(
                "Debes declarar 'target_arn' (variable del pipeline) o "
                "'target_name' (nombre de otra cola declarada en sqs_queues)"
            )
        return self


#################################################
# SQS Queue
#################################################

class SQSQueue(StrictModel):
    name:                             str
    fifo:                             bool                    = False
    content_based_deduplication:      bool                    = False
    visibility_timeout:               int                     = Field(default=30,     ge=0,  le=43200)
    message_retention_seconds:        int                     = Field(default=345600, ge=60, le=1209600)
    delay_seconds:                    int                     = Field(default=0,      ge=0,  le=900)
    maximum_message_size:             int                     = Field(default=262144, ge=1024, le=262144)
    receive_message_wait_time_seconds: int                    = Field(default=0,      ge=0,  le=20)
    dead_letter_queue:                Optional[DeadLetterQueue] = None
    allow_sns_publish_from_topic:     Optional[str]           = None   
    tags:                             Optional[dict]          = {}

    @field_validator('name')
    @classmethod
    def validate_queue_name(cls, v):
        if not re.match(r'^[a-zA-Z0-9_\-]{1,80}$', v):
            raise ValueError(
                f"nombre de cola '{v}' inválido. "
                f"Solo letras, números, guiones y guiones bajos. Máximo 80 caracteres."
            )
        return v

    @model_validator(mode='after')
    def validate_fifo_deduplication(self):
        if self.content_based_deduplication and not self.fifo:
            raise ValueError(
                f"cola '{self.name}': 'content_based_deduplication' solo aplica "
                f"en colas FIFO ('fifo: true')"
            )
        return self


#################################################
# SNS — Subscription
#################################################

class SNSSubscription(StrictModel):
    protocol:            SNSProtocolEnum
    endpoint:            Optional[str]           = None    
    queue:               Optional[str]           = None   
    filter_policy:       Optional[Any]           = None    
    filter_policy_scope: Optional[FilterPolicyScopeEnum] = None
    raw_message_delivery: bool                   = False
    redrive_policy:      Optional[str]           = None

    @field_validator('filter_policy', mode='before')
    @classmethod
    def parse_filter_policy(cls, v):
        if isinstance(v, str):
            try:
                return json.loads(v)
            except json.JSONDecodeError as e:
                raise ValueError(
                    f"'filter_policy' no es un JSON válido: {e}"
                )
        return v

    @field_validator('redrive_policy')
    @classmethod
    def validate_redrive_arn(cls, v):
        if v is None:
            return v
        return validate_arn_or_variable(v, service_hint="SQS redrive policy")

    @model_validator(mode='after')
    def validate_endpoint_or_queue(self):
        if self.protocol == SNSProtocolEnum.sqs:
            if self.queue and self.endpoint:
                raise ValueError(
                    "Para protocol='sqs' declara 'queue' (nombre de cola local) "
                    "O 'endpoint' (ARN/variable), no ambos"
                )
            if not self.queue and not self.endpoint:
                raise ValueError(
                    "Para protocol='sqs' debes declarar 'queue' (nombre de cola "
                    "declarada en sqs_queues) o 'endpoint' (ARN/variable del pipeline)"
                )
        else:
            if not self.endpoint:
                raise ValueError(
                    f"'endpoint' es requerido para protocol='{self.protocol}'"
                )
        return self

    @model_validator(mode='after')
    def validate_filter_policy_scope(self):
        if self.filter_policy_scope and not self.filter_policy:
            raise ValueError(
                "'filter_policy_scope' solo aplica cuando se declara 'filter_policy'"
            )
        return self

    @model_validator(mode='after')
    def validate_raw_delivery_only_sqs_http(self):
        if self.raw_message_delivery and self.protocol not in (
            SNSProtocolEnum.sqs, SNSProtocolEnum.http, SNSProtocolEnum.https
        ):
            raise ValueError(
                f"'raw_message_delivery' solo aplica para protocol sqs, http o https. "
                f"Actual: '{self.protocol}'"
            )
        return self


#################################################
# SNS Topic
#################################################

class SNSTopic(StrictModel):
    name:                        str
    fifo:                        bool                      = False
    content_based_deduplication: bool                      = False
    kms_master_key_id:           Optional[str]             = None
    policy_statements:           List[dict]                = []
    subscriptions:               List[SNSSubscription]    = []
    tags:                        Optional[dict]            = {}

    @field_validator('name')
    @classmethod
    def validate_topic_name(cls, v):
        if not re.match(r'^[a-zA-Z0-9_\-]{1,256}$', v):
            raise ValueError(
                f"nombre de topic '{v}' inválido. "
                f"Solo letras, números, guiones y guiones bajos. Máximo 256 caracteres."
            )
        return v

    @field_validator('kms_master_key_id')
    @classmethod
    def validate_kms(cls, v):
        if v is None:
            return v
        if re.match(r'^\$\(.+\)$', v):
            return v
        if re.match(r'^alias/.+$', v):
            return v
        if re.match(r'^[a-f0-9\-]{36}$', v):
            return v
        if re.match(r'^arn:aws:kms:', v):
            raise ValueError(
                f"No se permite declarar el KMS ARN directamente. "
                f"Use alias/nombre-clave, UUID o $(VARIABLE_PIPELINE)"
            )
        raise ValueError(
            f"kms_master_key_id='{v}' no tiene formato válido. "
            f"Use: alias/nombre-clave, UUID o $(VARIABLE)"
        )

    @model_validator(mode='after')
    def validate_fifo_deduplication(self):
        if self.content_based_deduplication and not self.fifo:
            raise ValueError(
                f"topic '{self.name}': 'content_based_deduplication' solo aplica "
                f"en topics FIFO ('fifo: true')"
            )
        return self

    @model_validator(mode='after')
    def validate_fifo_no_http_subscriptions(self):
        if self.fifo:
            unsupported = {
                SNSProtocolEnum.http, SNSProtocolEnum.https,
                SNSProtocolEnum.email, SNSProtocolEnum.email_json,
                SNSProtocolEnum.sms,
            }
            for sub in self.subscriptions:
                if sub.protocol in unsupported:
                    raise ValueError(
                        f"topic FIFO '{self.name}': protocol='{sub.protocol}' "
                        f"no está soportado en topics FIFO. "
                        f"Protocolos válidos: sqs, lambda, firehose, application"
                    )
        return self


#################################################
# MESSAGING (root)
#################################################

class Messaging(StrictModel):
    depends_on:  List[str]                = []
    sqs_queues:  Optional[List[SQSQueue]] = None
    sns_topics:  Optional[List[SNSTopic]] = None

    @model_validator(mode='after')
    def validate_sqs_names_unique(self):
        if self.sqs_queues:
            names = [q.name for q in self.sqs_queues]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de sqs_queues deben ser únicos")
        return self

    @model_validator(mode='after')
    def validate_sns_names_unique(self):
        if self.sns_topics:
            names = [t.name for t in self.sns_topics]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de sns_topics deben ser únicos")
        return self

    @model_validator(mode='after')
    def validate_dlq_target_names_exist(self):
        if not self.sqs_queues:
            return self
        queue_names = {q.name for q in self.sqs_queues}
        for queue in self.sqs_queues:
            if queue.dead_letter_queue and queue.dead_letter_queue.target_name:
                target = queue.dead_letter_queue.target_name
                if target not in queue_names:
                    raise ValueError(
                        f"sqs_queues '{queue.name}': dead_letter_queue.target_name='{target}' "
                        f"no existe en sqs_queues. "
                        f"Colas disponibles: {sorted(queue_names)}"
                    )
                if target == queue.name:
                    raise ValueError(
                        f"sqs_queues '{queue.name}': una cola no puede ser su propia DLQ"
                    )
        return self

    @model_validator(mode='after')
    def validate_sns_subscription_queue_names_exist(self):
        if not self.sns_topics:
            return self
        queue_names = {q.name for q in self.sqs_queues or []}
        for topic in self.sns_topics:
            for sub in topic.subscriptions:
                if sub.protocol == SNSProtocolEnum.sqs and sub.queue:
                    if sub.queue not in queue_names:
                        raise ValueError(
                            f"sns_topics '{topic.name}': subscription.queue='{sub.queue}' "
                            f"no existe en sqs_queues. "
                            f"Colas disponibles: {sorted(queue_names)}"
                        )
        return self

    @model_validator(mode='after')
    def validate_allow_sns_publish_topic_names_exist(self):
        if not self.sqs_queues:
            return self
        topic_names = {t.name for t in self.sns_topics or []}
        for queue in self.sqs_queues:
            if queue.allow_sns_publish_from_topic:
                topic = queue.allow_sns_publish_from_topic
                if topic not in topic_names:
                    raise ValueError(
                        f"sqs_queues '{queue.name}': allow_sns_publish_from_topic='{topic}' "
                        f"no existe en sns_topics. "
                        f"Topics disponibles: {sorted(topic_names)}"
                    )
        return self

    @model_validator(mode='after')
    def validate_fifo_consistency_dlq(self):
        if not self.sqs_queues:
            return self
        queue_map = {q.name: q for q in self.sqs_queues}
        for queue in self.sqs_queues:
            if queue.fifo and queue.dead_letter_queue and queue.dead_letter_queue.target_name:
                target = queue_map.get(queue.dead_letter_queue.target_name)
                if target and not target.fifo:
                    raise ValueError(
                        f"sqs_queues '{queue.name}': es una cola FIFO pero su DLQ "
                        f"'{queue.dead_letter_queue.target_name}' no es FIFO. "
                        f"Las colas FIFO solo pueden tener DLQs FIFO"
                    )
        return self