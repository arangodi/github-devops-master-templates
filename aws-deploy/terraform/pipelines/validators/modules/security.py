import re
from typing import Optional, List, Any
from pydantic import field_validator, model_validator, Field
from validators.base import StrictModel, validate_arn_or_variable

_VALID_VALIDATION_METHODS = ["DNS", "EMAIL"]


class Certificate(StrictModel):
    name:                      str
    domain:                    str
    create:                    bool            = True
    create_zone:               bool            = False
    subject_alternative_names: List[str]       = []
    validation_method:         str             = "DNS"
    arn:                       Optional[str]   = None  
    tags:                      Optional[dict]  = {}

    @field_validator('domain')
    @classmethod
    def validate_domain(cls, v):
        pattern = r'^(\*\.)?([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
        if not re.match(pattern, v):
            raise ValueError(
                f"domain='{v}' no tiene formato válido. "
                f"Ejemplos: example.com, sub.example.com, *.example.com"
            )
        return v

    @field_validator('subject_alternative_names')
    @classmethod
    def validate_sans(cls, v):
        pattern = r'^(\*\.)?([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
        for san in v:
            if not re.match(pattern, san):
                raise ValueError(
                    f"subject_alternative_name='{san}' no tiene formato de dominio válido."
                )
        return v

    @field_validator('validation_method')
    @classmethod
    def validate_validation_method(cls, v):
        if v not in _VALID_VALIDATION_METHODS:
            raise ValueError(
                f"validation_method='{v}' no es válido. "
                f"Valores válidos: {_VALID_VALIDATION_METHODS}"
            )
        return v

    @field_validator('arn')
    @classmethod
    def validate_arn(cls, v):
        if v is None:
            return v
        return validate_arn_or_variable(v, service_hint="certificado ACM")

    @model_validator(mode='after')
    def validate_existing_arn_requires_create_false(self):
        if self.arn and self.create:
            raise ValueError(
                f"certificate '{self.name}': 'arn' solo aplica cuando 'create: false'"
            )
        return self

    @model_validator(mode='after')
    def validate_create_requires_domain(self):
        if self.create and not self.domain:
            raise ValueError(
                f"certificate '{self.name}': 'domain' es requerido cuando 'create: true'"
            )
        return self


_VALID_SECRET_TYPES = ["string", "json", "binary"]


class Secret(StrictModel):
    name:                 str
    create:               bool           = True
    existing_secret_arn:  Optional[str]  = None
    description:          Optional[str]  = None
    kms_key_id:           Optional[str]  = None
    recovery_window_days: Optional[int]  = Field(default=None, ge=0, le=30)
    secret_type:          str            = "string"
    enable_rotation:      bool           = False
    rotation_lambda_arn:  Optional[str]  = None
    rotation_days:        int            = Field(default=30, ge=1, le=365)
    rotation_duration:    str            = "2h"
    reader_role_arns:     List[str]      = []
    writer_role_arns:     List[str]      = []
    admin_role_arns:      List[str]      = []
    secret_value:         Optional[Any]  = None   
    tags:                 Optional[dict] = {}

    @field_validator('secret_type')
    @classmethod
    def validate_secret_type(cls, v):
        if v not in _VALID_SECRET_TYPES:
            raise ValueError(
                f"secret_type='{v}' no es válido. "
                f"Valores válidos: {_VALID_SECRET_TYPES}"
            )
        return v

    @field_validator('existing_secret_arn')
    @classmethod
    def validate_existing_secret_arn(cls, v):
        if v is None:
            return v
        return validate_arn_or_variable(v, service_hint="secret existente")

    @field_validator('rotation_lambda_arn')
    @classmethod
    def validate_rotation_lambda_arn(cls, v):
        if v is None:
            return v
        return validate_arn_or_variable(v, service_hint="Lambda de rotación")

    @field_validator('kms_key_id')
    @classmethod
    def validate_kms_key_id(cls, v):
        if v is None:
            return v
        if re.match(r'^\$\(.+\)$', v):
            return v
        if re.match(r'^[a-f0-9\-]{36}$', v):         
            return v
        if re.match(r'^alias/.+$', v):                  
            return v
        if re.match(r'^arn:aws:kms:[a-z0-9\-]+:\d{12}:.+$', v):
            raise ValueError(
                f"No se permite declarar el KMS ARN directamente. "
                f"Use una referencia a variable del pipeline: $(NOMBRE_VARIABLE), "
                f"un key-id UUID o un alias (alias/nombre-clave)"
            )
        raise ValueError(
            f"kms_key_id='{v}' no tiene formato válido. "
            f"Use: UUID de clave, alias/nombre-clave o $(VARIABLE_PIPELINE)"
        )

    @field_validator('rotation_duration')
    @classmethod
    def validate_rotation_duration(cls, v):
        if not re.match(r'^\d+[hd]$', v):
            raise ValueError(
                f"rotation_duration='{v}' no tiene formato válido. "
                f"Use formato '<número>h' o '<número>d'. Ejemplos: '2h', '1d', '24h'"
            )
        return v

    @field_validator('reader_role_arns', 'writer_role_arns', 'admin_role_arns')
    @classmethod
    def validate_role_arns(cls, v):
        for arn in v:
            validate_arn_or_variable(arn, service_hint="IAM role")
        return v

    @model_validator(mode='after')
    def validate_existing_secret_requires_create_false(self):
        if self.existing_secret_arn and self.create:
            raise ValueError(
                f"secret '{self.name}': 'existing_secret_arn' solo aplica cuando 'create: false'"
            )
        return self

    @model_validator(mode='after')
    def validate_rotation_config(self):
        if self.enable_rotation and not self.rotation_lambda_arn:
            raise ValueError(
                f"secret '{self.name}': 'rotation_lambda_arn' es requerido "
                f"cuando 'enable_rotation: true'"
            )
        if self.rotation_lambda_arn and not self.enable_rotation:
            raise ValueError(
                f"secret '{self.name}': 'rotation_lambda_arn' solo aplica "
                f"cuando 'enable_rotation: true'"
            )
        return self

    @model_validator(mode='after')
    def validate_secret_value_not_on_existing(self):
        if not self.create and self.secret_value is not None:
            raise ValueError(
                f"secret '{self.name}': 'secret_value' no aplica cuando 'create: false'"
            )
        return self

class Security(StrictModel):
    depends_on:   List[str]               = []
    certificates: Optional[List[Certificate]] = None
    secrets:      Optional[List[Secret]]      = None

    @model_validator(mode='after')
    def validate_certificate_names_unique(self):
        if self.certificates:
            names = [c.name for c in self.certificates]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de certificates deben ser únicos")
        return self

    @model_validator(mode='after')
    def validate_secret_names_unique(self):
        if self.secrets:
            names = [s.name for s in self.secrets]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de secrets deben ser únicos")
        return self