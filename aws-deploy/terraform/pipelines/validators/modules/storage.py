import re
from typing import Optional, List, Literal
from pydantic import field_validator, model_validator, Field
from validators.base import StrictModel


class S3Logging(StrictModel):
    target_bucket: str
    target_prefix: str = "logs/"


_VALID_S3_EVENT_PREFIXES = [
    "s3:ObjectCreated:",
    "s3:ObjectRemoved:",
    "s3:ObjectRestore:",
    "s3:ReducedRedundancyLostObject",
    "s3:Replication:",
    "s3:LifecycleExpiration:",
    "s3:LifecycleTransition:",
    "s3:IntelligentTiering",
    "s3:ObjectTagging:",
    "s3:ObjectAcl:",
]


class S3Notifications(StrictModel):
    lambda_arn: Optional[str] = None
    sqs_arn:    Optional[str] = None
    sns_arn:    Optional[str] = None
    events:     List[str]     = ["s3:ObjectCreated:*"]
    prefix:     str           = ""
    suffix:     str           = ""

    @field_validator('events')
    @classmethod
    def validate_events(cls, v):
        for event in v:
            if not any(event.startswith(p) for p in _VALID_S3_EVENT_PREFIXES):
                raise ValueError(
                    f"Evento S3 inválido: '{event}'. "
                    f"Debe comenzar con uno de: {_VALID_S3_EVENT_PREFIXES}"
                )
        return v

    @model_validator(mode='after')
    def validate_at_least_one_arn(self):
        if not any([self.lambda_arn, self.sqs_arn, self.sns_arn]):
            raise ValueError(
                "Si declara 'notifications', debe tener al menos "
                "lambda_arn, sqs_arn o sns_arn"
            )
        return self


class S3Replication(StrictModel):
    role_arn:           str
    destination_bucket: str
    destination_region: str
    replicate_delete:   bool = False

    @field_validator('role_arn')
    @classmethod
    def validate_role_arn(cls, v):
        if not re.match(r'^arn:aws:iam::\d{12}:.+$', v):
            raise ValueError(
                f"'{v}' no es un IAM ARN válido. "
                f"Formato esperado: arn:aws:iam::123456789012:role/..."
            )
        return v

    @field_validator('destination_bucket')
    @classmethod
    def validate_bucket_arn(cls, v):
        if not re.match(r'^arn:aws:s3:::.+$', v):
            raise ValueError(
                f"'{v}' no es un S3 ARN válido. "
                f"Formato esperado: arn:aws:s3:::nombre-bucket"
            )
        return v

    @field_validator('destination_region')
    @classmethod
    def validate_region(cls, v):
        if not re.match(r'^[a-z]{2}-[a-z]+-\d$', v):
            raise ValueError(
                f"destination_region='{v}' no tiene formato válido. "
                f"Ejemplo: us-east-1, eu-west-2, sa-east-1"
            )
        return v


_VALID_STORAGE_CLASSES = [
    "STANDARD_IA", "ONEZONE_IA", "INTELLIGENT_TIERING",
    "GLACIER", "GLACIER_IR", "DEEP_ARCHIVE",
]


class S3LifecycleTransition(StrictModel):
    days:          int = Field(ge=1)
    storage_class: str

    @field_validator('storage_class')
    @classmethod
    def validate_storage_class(cls, v):
        if v not in _VALID_STORAGE_CLASSES:
            raise ValueError(
                f"storage_class='{v}' no es válido. "
                f"Valores válidos: {_VALID_STORAGE_CLASSES}"
            )
        return v


class S3LifecycleRule(StrictModel):
    id:                              str
    enabled:                         bool                           = True
    prefix:                          Optional[str]                  = None
    tags:                            Optional[dict]                 = None
    expiration_days:                 Optional[int]                  = Field(default=None, ge=1)
    noncurrent_version_expiration_days: Optional[int]               = Field(default=None, ge=1)
    transitions:                     Optional[List[S3LifecycleTransition]] = None
    noncurrent_version_transitions:  Optional[List[S3LifecycleTransition]] = None
    abort_incomplete_multipart_days: Optional[int]                  = Field(default=None, ge=1)

    @model_validator(mode='after')
    def validate_at_least_one_action(self):
        has_action = any([
            self.expiration_days,
            self.noncurrent_version_expiration_days,
            self.transitions,
            self.noncurrent_version_transitions,
            self.abort_incomplete_multipart_days,
        ])
        if not has_action:
            raise ValueError(
                f"lifecycle_rule '{self.id}': debe tener al menos una acción "
                f"(expiration_days, transitions, abort_incomplete_multipart_days, etc.)"
            )
        return self


class S3Bucket(StrictModel):
    name:                str
    versioning:          bool                           = False
    encryption:          bool                           = True
    block_public_access: bool                           = True
    bucket_policy:       Optional[str]                  = None
    lifecycle_rules:     List[S3LifecycleRule]          = []  
    logging:             Optional[S3Logging]            = None
    notifications:       Optional[S3Notifications]      = None
    replication:         Optional[S3Replication]        = None
    tags:                Optional[dict]                 = {}

    @field_validator('name')
    @classmethod
    def validate_bucket_name(cls, v):
        if not re.match(r'^[a-z0-9][a-z0-9\-]{1,61}[a-z0-9]$', v):
            raise ValueError(
                f"nombre de bucket S3 inválido: '{v}'. "
                f"Debe tener 3-63 caracteres, solo minúsculas, números y guiones, "
                f"sin empezar ni terminar con guion."
            )
        if re.match(r'^\d+\.\d+\.\d+\.\d+$', v):
            raise ValueError(f"El nombre del bucket no puede tener formato de IP: '{v}'")
        return v

    @model_validator(mode='after')
    def validate_replication_requires_versioning(self):
        if self.replication and not self.versioning:
            raise ValueError(
                f"bucket '{self.name}': 'replication' requiere 'versioning: true'"
            )
        return self

    @model_validator(mode='after')
    def validate_lifecycle_rule_ids_unique(self):
        if self.lifecycle_rules:
            ids = [r.id for r in self.lifecycle_rules]
            if len(ids) != len(set(ids)):
                raise ValueError(
                    f"bucket '{self.name}': los IDs de lifecycle_rules deben ser únicos"
                )
        return self



class Storage(StrictModel):
    depends_on: List[str]                = []
    s3_buckets: Optional[List[S3Bucket]] = None

    @model_validator(mode='after')
    def validate_bucket_names_unique(self):
        if self.s3_buckets:
            names = [b.name for b in self.s3_buckets]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de s3_buckets deben ser únicos")
        return self