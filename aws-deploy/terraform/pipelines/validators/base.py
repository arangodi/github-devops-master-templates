from enum import Enum
from pydantic import BaseModel, ConfigDict
import re


#################################################
# BASE MODEL
#################################################

class StrictModel(BaseModel):
    model_config = ConfigDict(extra='forbid')


#################################################
# ENUMS
#################################################

class EnvironmentEnum(str, Enum):
    dev = "dev"
    uat = "uat"
    pdn = "pdn"
    qc  = "qc"

class LoadBalancerTypeEnum(str, Enum):
    application = "application"
    network     = "network"

class SubnetGroupEnum(str, Enum):
    EC2 = "EC2"
    ELB = "ELB"

class ImageTagMutabilityEnum(str, Enum):
    MUTABLE   = "MUTABLE"
    IMMUTABLE = "IMMUTABLE"

class EncryptionTypeEnum(str, Enum):
    KMS    = "KMS"
    AES256 = "AES256"

#################################################
# VALIDADOR ARN O VARIABLE
#################################################

def validate_arn_or_variable(v: str, service_hint: str = None) -> str:
    """
    Acepta dos formatos:
      - Referencia a variable del pipeline: $(NOMBRE_VARIABLE)
      - ARN real de AWS — se rechaza pidiendo que use variable

    Si detecta un ARN real lanza error con sugerencia de cómo declararlo
    como variable.
    """
    if v is None:
        return v

    if re.match(r'^\$\(.+\)$', v):
        return v

    if re.match(r'^arn:aws:[a-z0-9\-]+:[a-z0-9\-]*:\d{12}:.+$', v):
        hint = f" del {service_hint}" if service_hint else ""
        raise ValueError(
            f"No se permite declarar el ARN{hint} directamente en el YAML por seguridad. "
            f"Use una referencia a variable del pipeline.\n"
            f"  Incorrecto: {v}\n"
            f"  Correcto:   $(NOMBRE_VARIABLE)"
        )

    
    hint = f" del {service_hint}" if service_hint else ""
    raise ValueError(
        f"'{v}' no es un valor válido{hint}. "
        f"Use una referencia a variable del pipeline.\n"
        f"  Formato esperado: $(NOMBRE_VARIABLE)\n"
        f"  Ejemplo:          $(NLB_ARN)"
    )