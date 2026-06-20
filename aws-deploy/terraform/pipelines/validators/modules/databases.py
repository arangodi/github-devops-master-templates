import re
from typing import Optional, List
from enum import Enum
from pydantic import field_validator, model_validator, Field
from validators.base import StrictModel, validate_arn_or_variable


#################################################
# ENUMS
#################################################

class AttributeTypeEnum(str, Enum):
    S = "S"   # String
    N = "N"   # Number
    B = "B"   # Binary


class BillingModeEnum(str, Enum):
    PROVISIONED    = "PROVISIONED"
    PAY_PER_REQUEST = "PAY_PER_REQUEST"


class TableClassEnum(str, Enum):
    STANDARD           = "STANDARD"
    STANDARD_INFREQUENT = "STANDARD_INFREQUENT_ACCESS"


class StreamViewTypeEnum(str, Enum):
    KEYS_ONLY        = "KEYS_ONLY"
    NEW_IMAGE        = "NEW_IMAGE"
    OLD_IMAGE        = "OLD_IMAGE"
    NEW_AND_OLD_IMAGES = "NEW_AND_OLD_IMAGES"


class ProjectionTypeEnum(str, Enum):
    ALL      = "ALL"
    KEYS_ONLY = "KEYS_ONLY"
    INCLUDE  = "INCLUDE"


#################################################
# ATTRIBUTE
#################################################

class DynamoDBAttribute(StrictModel):
    name: str
    type: AttributeTypeEnum

    @field_validator('name')
    @classmethod
    def validate_name(cls, v):
        if not v or len(v) < 1 or len(v) > 255:
            raise ValueError("El nombre del atributo debe tener entre 1 y 255 caracteres")
        return v


#################################################
# GLOBAL SECONDARY INDEX
#################################################

class GlobalSecondaryIndex(StrictModel):
    name:                str
    hash_key:            str
    hash_key_type:       AttributeTypeEnum  = AttributeTypeEnum.S
    range_key:           Optional[str]      = None
    range_key_type:      AttributeTypeEnum  = AttributeTypeEnum.S
    projection_type:     ProjectionTypeEnum = ProjectionTypeEnum.ALL
    non_key_attributes:  Optional[List[str]] = None
    read_capacity:       Optional[int]      = Field(default=None, ge=1)
    write_capacity:      Optional[int]      = Field(default=None, ge=1)

    @field_validator('name')
    @classmethod
    def validate_index_name(cls, v):
        if not re.match(r'^[a-zA-Z0-9_\-\.]+$', v):
            raise ValueError(
                f"nombre de GSI '{v}' inválido. "
                f"Solo se permiten letras, números, guiones, puntos y guiones bajos"
            )
        if len(v) < 3 or len(v) > 255:
            raise ValueError(f"nombre de GSI debe tener entre 3 y 255 caracteres")
        return v

    @model_validator(mode='after')
    def validate_non_key_attributes_requires_include(self):
        if self.non_key_attributes and self.projection_type != ProjectionTypeEnum.INCLUDE:
            raise ValueError(
                f"GSI '{self.name}': 'non_key_attributes' solo aplica cuando "
                f"'projection_type: INCLUDE'"
            )
        if self.projection_type == ProjectionTypeEnum.INCLUDE and not self.non_key_attributes:
            raise ValueError(
                f"GSI '{self.name}': 'projection_type: INCLUDE' requiere declarar "
                f"'non_key_attributes' con al menos un atributo"
            )
        return self


#################################################
# LOCAL SECONDARY INDEX
#################################################

class LocalSecondaryIndex(StrictModel):
    name:               str
    range_key:          str
    range_key_type:     AttributeTypeEnum  = AttributeTypeEnum.S
    projection_type:    ProjectionTypeEnum = ProjectionTypeEnum.ALL
    non_key_attributes: Optional[List[str]] = None

    @field_validator('name')
    @classmethod
    def validate_index_name(cls, v):
        if not re.match(r'^[a-zA-Z0-9_\-\.]+$', v):
            raise ValueError(
                f"nombre de LSI '{v}' inválido. "
                f"Solo se permiten letras, números, guiones, puntos y guiones bajos"
            )
        if len(v) < 3 or len(v) > 255:
            raise ValueError(f"nombre de LSI debe tener entre 3 y 255 caracteres")
        return v

    @model_validator(mode='after')
    def validate_non_key_attributes_requires_include(self):
        if self.non_key_attributes and self.projection_type != ProjectionTypeEnum.INCLUDE:
            raise ValueError(
                f"LSI '{self.name}': 'non_key_attributes' solo aplica cuando "
                f"'projection_type: INCLUDE'"
            )
        if self.projection_type == ProjectionTypeEnum.INCLUDE and not self.non_key_attributes:
            raise ValueError(
                f"LSI '{self.name}': 'projection_type: INCLUDE' requiere declarar "
                f"'non_key_attributes' con al menos un atributo"
            )
        return self


#################################################
# AUTOSCALING
#################################################

class DynamoDBAutoscaling(StrictModel):
    read_max_capacity:   int   = Field(default=100, ge=1)
    write_max_capacity:  int   = Field(default=100, ge=1)
    read_target:         float = Field(default=70.0, gt=0, le=100)
    write_target:        float = Field(default=70.0, gt=0, le=100)
    scale_in_cooldown:   int   = Field(default=60, ge=0)
    scale_out_cooldown:  int   = Field(default=60, ge=0)


#################################################
# DYNAMODB TABLE
#################################################

class DynamoDBTable(StrictModel):
    name:                str
    create:              bool                             = True
    existing_table_name: Optional[str]                   = None
    hash_key:            str
    hash_key_type:       AttributeTypeEnum               = AttributeTypeEnum.S
    range_key:           Optional[str]                   = None
    range_key_type:      AttributeTypeEnum               = AttributeTypeEnum.S
    attributes:          List[DynamoDBAttribute]         = []
    billing_mode:        BillingModeEnum                 = BillingModeEnum.PAY_PER_REQUEST
    table_class:         TableClassEnum                  = TableClassEnum.STANDARD
    read_capacity:       int                             = Field(default=5, ge=1)
    write_capacity:      int                             = Field(default=5, ge=1)
    enable_autoscaling:  bool                            = False
    autoscaling:         Optional[DynamoDBAutoscaling]   = None
    global_secondary_indexes: List[GlobalSecondaryIndex] = []
    local_secondary_indexes:  List[LocalSecondaryIndex]  = []
    stream_enabled:      bool                            = False
    stream_view_type:    StreamViewTypeEnum              = StreamViewTypeEnum.NEW_AND_OLD_IMAGES
    ttl_enabled:         bool                            = False
    ttl_attribute_name:  str                             = "ttl"
    point_in_time_recovery_enabled: bool                 = True
    encryption_enabled:  bool                            = True
    kms_key_arn:         Optional[str]                   = None
    deletion_protection_enabled: bool                    = False

    tags:                Optional[dict]                  = {}

    @field_validator('name')
    @classmethod
    def validate_table_name(cls, v):
        if not re.match(r'^[a-zA-Z0-9_\-\.]+$', v):
            raise ValueError(
                f"nombre de tabla '{v}' inválido. "
                f"Solo se permiten letras, números, guiones, puntos y guiones bajos"
            )
        if len(v) < 3 or len(v) > 255:
            raise ValueError("El nombre de la tabla debe tener entre 3 y 255 caracteres")
        return v

    @field_validator('kms_key_arn')
    @classmethod
    def validate_kms_key_arn(cls, v):
        if v is None:
            return v
        return validate_arn_or_variable(v, service_hint="KMS key de DynamoDB")

    @model_validator(mode='after')
    def validate_existing_table_requires_create_false(self):
        if self.existing_table_name and self.create:
            raise ValueError(
                f"tabla '{self.name}': 'existing_table_name' solo aplica "
                f"cuando 'create: false'"
            )
        return self

    @model_validator(mode='after')
    def validate_provisioned_requires_capacity(self):
        if self.billing_mode == BillingModeEnum.PAY_PER_REQUEST and (
            self.enable_autoscaling
        ):
            raise ValueError(
                f"tabla '{self.name}': 'enable_autoscaling' solo aplica con "
                f"'billing_mode: PROVISIONED'"
            )
        return self

    @model_validator(mode='after')
    def validate_autoscaling_config(self):
        if self.enable_autoscaling:
            if self.billing_mode != BillingModeEnum.PROVISIONED:
                raise ValueError(
                    f"tabla '{self.name}': 'enable_autoscaling: true' requiere "
                    f"'billing_mode: PROVISIONED'"
                )
            config = self.autoscaling or DynamoDBAutoscaling()
            if config.read_max_capacity < self.read_capacity:
                raise ValueError(
                    f"tabla '{self.name}': 'autoscaling.read_max_capacity' "
                    f"({config.read_max_capacity}) no puede ser menor que "
                    f"'read_capacity' ({self.read_capacity})"
                )
            if config.write_max_capacity < self.write_capacity:
                raise ValueError(
                    f"tabla '{self.name}': 'autoscaling.write_max_capacity' "
                    f"({config.write_max_capacity}) no puede ser menor que "
                    f"'write_capacity' ({self.write_capacity})"
                )
        return self

    @model_validator(mode='after')
    def validate_stream_view_type(self):
        if self.stream_view_type != StreamViewTypeEnum.NEW_AND_OLD_IMAGES and not self.stream_enabled:
            raise ValueError(
                f"tabla '{self.name}': 'stream_view_type' solo aplica cuando "
                f"'stream_enabled: true'"
            )
        return self

    @model_validator(mode='after')
    def validate_kms_requires_encryption(self):
        if self.kms_key_arn and not self.encryption_enabled:
            raise ValueError(
                f"tabla '{self.name}': 'kms_key_arn' requiere "
                f"'encryption_enabled: true'"
            )
        return self

    @model_validator(mode='after')
    def validate_lsi_requires_range_key(self):
        if self.local_secondary_indexes and not self.range_key:
            raise ValueError(
                f"tabla '{self.name}': 'local_secondary_indexes' requiere que la tabla "
                f"tenga 'range_key' declarado"
            )
        return self

    @model_validator(mode='after')
    def validate_gsi_names_unique(self):
        if self.global_secondary_indexes:
            names = [g.name for g in self.global_secondary_indexes]
            if len(names) != len(set(names)):
                raise ValueError(
                    f"tabla '{self.name}': los nombres de global_secondary_indexes "
                    f"deben ser únicos"
                )
        return self

    @model_validator(mode='after')
    def validate_lsi_names_unique(self):
        if self.local_secondary_indexes:
            names = [l.name for l in self.local_secondary_indexes]
            if len(names) != len(set(names)):
                raise ValueError(
                    f"tabla '{self.name}': los nombres de local_secondary_indexes "
                    f"deben ser únicos"
                )
        return self

    @model_validator(mode='after')
    def validate_index_keys_have_attributes(self):
        """
        DynamoDB exige que todo atributo usado en un GSI/LSI esté declarado
        en la lista de attributes (además de hash_key y range_key de la tabla).
        """
        if not self.global_secondary_indexes and not self.local_secondary_indexes:
            return self

        declared = {self.hash_key, self.range_key} | {a.name for a in self.attributes}
        declared.discard(None)

        for gsi in self.global_secondary_indexes:
            for key in [gsi.hash_key, gsi.range_key]:
                if key and key not in declared:
                    raise ValueError(
                        f"tabla '{self.name}', GSI '{gsi.name}': "
                        f"atributo '{key}' no está declarado en 'attributes'. "
                        f"Todos los atributos usados en índices deben estar en 'attributes'"
                    )

        for lsi in self.local_secondary_indexes:
            if lsi.range_key not in declared:
                raise ValueError(
                    f"tabla '{self.name}', LSI '{lsi.name}': "
                    f"atributo '{lsi.range_key}' no está declarado en 'attributes'. "
                    f"Todos los atributos usados en índices deben estar en 'attributes'"
                )
        return self

    @model_validator(mode='after')
    def validate_lsi_limit(self):
        if self.local_secondary_indexes and len(self.local_secondary_indexes) > 5:
            raise ValueError(
                f"tabla '{self.name}': DynamoDB permite máximo 5 local_secondary_indexes, "
                f"se declararon {len(self.local_secondary_indexes)}"
            )
        return self

    @model_validator(mode='after')
    def validate_gsi_limit(self):
        if self.global_secondary_indexes and len(self.global_secondary_indexes) > 20:
            raise ValueError(
                f"tabla '{self.name}': DynamoDB permite máximo 20 global_secondary_indexes, "
                f"se declararon {len(self.global_secondary_indexes)}"
            )
        return self


#################################################
# DATABASES (root)
#################################################

class Databases(StrictModel):
    depends_on:      List[str]                    = []
    dynamodb_tables: Optional[List[DynamoDBTable]] = None

    @model_validator(mode='after')
    def validate_table_names_unique(self):
        if self.dynamodb_tables:
            names = [t.name for t in self.dynamodb_tables]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de dynamodb_tables deben ser únicos")
        return self