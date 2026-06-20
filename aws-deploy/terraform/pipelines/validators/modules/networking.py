import re
from typing import Optional, List
from enum import Enum
from pydantic import field_validator, model_validator, Field
from validators.base import StrictModel, LoadBalancerTypeEnum, SubnetGroupEnum, validate_arn_or_variable


#################################################
# ELB
#################################################
class ELB(StrictModel):
    name:                     str
    load_balancer_type:       LoadBalancerTypeEnum = LoadBalancerTypeEnum.application
    subnet_group:             SubnetGroupEnum      = SubnetGroupEnum.ELB   # FIXED: default ELB (alineado con main.tf)
    internal:                 bool                 = True
    port:                     int                  = Field(default=443, ge=1, le=65535)
    ingress_cidr:             Optional[str]        = "10.0.0.0/8"
    certificate_arn:          Optional[str]        = None
    ssl_policy:               Optional[str]        = None
    idle_timeout:             int                  = 60
    deletion_protection:      bool                 = True
    default_target_group_arn: Optional[str]        = None  # solo NLB, no pasa al módulo directamente
    create:                   bool                 = True
    existing_arn:             Optional[str]        = None
    existing_listener_arn:    Optional[str]        = None
    existing_sg_id:           Optional[str]        = None
    tags:                     Optional[dict]       = {}

    @field_validator('ingress_cidr')
    @classmethod
    def validate_cidr(cls, v):
        if v is None:
            return v
        if not re.match(r'^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$', v):
            raise ValueError(f"'{v}' no es un CIDR válido. Formato esperado: 10.0.0.0/8")
        return v

    @field_validator('certificate_arn', 'existing_arn', 'existing_listener_arn', 'default_target_group_arn')
    @classmethod
    def validate_arn(cls, v):
        return validate_arn_or_variable(v, service_hint="ELB")

    @field_validator('existing_sg_id')
    @classmethod
    def validate_sg(cls, v):
        if v is None:
            return v
        if re.match(r'^\$\(.+\)$', v):
            return v
        if not v.startswith('sg-'):
            raise ValueError(
                f"'{v}' no es un Security Group ID válido. "
                f"Debe comenzar con 'sg-' o usar una variable: $(NOMBRE_VARIABLE)"
            )
        return v

    @model_validator(mode='after')
    def validate_create_false(self):
        if not self.create:
            if not self.existing_arn:
                raise ValueError("Si 'create: false' debe declarar 'existing_arn'")
            if not self.existing_listener_arn:
                raise ValueError("Si 'create: false' debe declarar 'existing_listener_arn'")
        return self

    @model_validator(mode='after')
    def validate_port_certificate(self):
        if self.load_balancer_type == LoadBalancerTypeEnum.application:
            if self.port == 443 and self.certificate_arn is None:
                raise ValueError(
                    "Puerto 443 requiere 'certificate_arn'. "
                    "Si no tienes certificado usa puerto 80 — el protocolo será HTTP"
                )
            if self.port == 80 and self.certificate_arn is not None:
                raise ValueError(
                    "Puerto 80 no requiere 'certificate_arn'. "
                    "Para usar certificado declara 'port: 443'"
                )
        return self

    @model_validator(mode='after')
    def validate_nlb_target_group(self):
        if self.default_target_group_arn and self.load_balancer_type != LoadBalancerTypeEnum.network:
            raise ValueError("'default_target_group_arn' solo aplica a NLB (load_balancer_type: network)")
        return self


#################################################
# ENI
#################################################
class ENI(StrictModel):
    name:               str
    subnet_group:       SubnetGroupEnum     = SubnetGroupEnum.EC2
    subnet_index:       int                 = 0
    private_ip:         Optional[str]       = None
    security_group_ids: Optional[List[str]] = None
    description:        Optional[str]       = None
    tags:               Optional[dict]      = {}

    @field_validator('name')
    @classmethod
    def validate_eni_name(cls, v):
        if not v or len(v) < 1 or len(v) > 128:
            raise ValueError("'name' debe tener entre 1 y 128 caracteres")
        return v

    @field_validator('subnet_index')
    @classmethod
    def validate_subnet_index(cls, v):
        if v < 0 or v > 10:
            raise ValueError(f"'subnet_index'={v} debe estar entre 0 y 10")
        return v

    @field_validator('private_ip')
    @classmethod
    def validate_private_ip(cls, v):
        if v is None:
            return v
        if not re.match(r'^\d{1,3}(\.\d{1,3}){3}$', v):
            raise ValueError(f"'{v}' no es una IP válida. Formato esperado: 10.0.0.1")
        return v

    @field_validator('security_group_ids')
    @classmethod
    def validate_sg_ids(cls, v):
        if v is None:
            return v
        if not isinstance(v, list):
            raise ValueError("'security_group_ids' debe ser una lista")
        for sg_id in v:
            if re.match(r'^\$\(.+\)$', sg_id):
                continue
            if not sg_id.startswith('sg-'):
                raise ValueError(
                    f"'{sg_id}' no es un Security Group ID válido. "
                    f"Debe comenzar con 'sg-' o usar una variable: $(NOMBRE_VARIABLE)"
                )
        return v

    @field_validator('description')
    @classmethod
    def validate_description(cls, v):
        if v is not None and len(v) > 255:
            raise ValueError("'description' no puede exceder 255 caracteres")
        return v


#################################################
# NAMESPACE
#################################################
class Namespace(StrictModel):
    name:   str
    create: bool           = True
    tags:   Optional[dict] = {}


#################################################
# ENUMS API GATEWAY
#################################################
class EndpointTypeEnum(str, Enum):
    REGIONAL = "REGIONAL"
    EDGE     = "EDGE"
    PRIVATE  = "PRIVATE"


class AuthorizationEnum(str, Enum):
    NONE               = "NONE"
    COGNITO_USER_POOLS = "COGNITO_USER_POOLS"


class LoggingLevelEnum(str, Enum):
    OFF   = "OFF"
    ERROR = "ERROR"
    INFO  = "INFO"


class QuotaPeriodEnum(str, Enum):
    DAY   = "DAY"
    WEEK  = "WEEK"
    MONTH = "MONTH"


class HttpMethodEnum(str, Enum):
    GET     = "GET"
    POST    = "POST"
    PUT     = "PUT"
    DELETE  = "DELETE"
    PATCH   = "PATCH"
    HEAD    = "HEAD"
    OPTIONS = "OPTIONS"
    ANY     = "ANY"


_VALID_INTEGRATION_TYPES = ["HTTP_PROXY", "HTTP", "AWS", "AWS_PROXY", "MOCK"]
_VALID_CONNECTION_TYPES  = ["VPC_LINK", "INTERNET"]


#################################################
# COGNITO
#################################################
class CognitoScope(StrictModel):
    name:        str
    description: str


class CognitoResourceServer(StrictModel):
    identifier: str
    name:       str
    scopes:     List[CognitoScope] = []


class Cognito(StrictModel):
    enabled:                   bool                                  = False
    client_name:               Optional[str]                         = None
    existing_user_pool_id:     Optional[str]                         = None
    domain_prefix:             Optional[str]                         = None
    enable_domain:             bool                                  = False
    access_token_validity:     int                                   = Field(default=60, ge=1, le=86400)
    id_token_validity:         int                                   = Field(default=60, ge=1, le=86400)
    refresh_token_validity:    int                                   = Field(default=30, ge=1, le=3650)
    enable_token_revocation:   bool                                  = True
    enable_client_credentials: bool                                  = False
    resource_servers:          Optional[List[CognitoResourceServer]] = []

    @field_validator('client_name')
    @classmethod
    def validate_client_name(cls, v):
        if v is None:
            return v
        if not re.match(r'^[a-zA-Z0-9\-\s]+$', v):
            raise ValueError(
                f"'{v}' no es un nombre válido. "
                f"Solo se permiten letras, números, guiones y espacios"
            )
        if len(v) < 1 or len(v) > 128:
            raise ValueError("'client_name' debe tener entre 1 y 128 caracteres")
        return v

    @field_validator('domain_prefix')
    @classmethod
    def validate_domain_prefix(cls, v):
        if v is None:
            return v
        if not re.match(r'^[a-z0-9\-]+$', v):
            raise ValueError(
                f"'{v}' no es un prefijo válido. "
                f"Solo se permiten letras minúsculas, números y guiones"
            )
        if len(v) < 1 or len(v) > 63:
            raise ValueError("'domain_prefix' debe tener entre 1 y 63 caracteres")
        return v

    @model_validator(mode='after')
    def validate_existing_user_pool(self):
        if self.existing_user_pool_id:
            if self.domain_prefix:
                raise ValueError(
                    "No se puede declarar 'domain_prefix' si se usa un "
                    "User Pool existente — el dominio ya existe"
                )
            if self.resource_servers:
                raise ValueError(
                    "No se puede declarar 'resource_servers' si se usa un "
                    "User Pool existente — los resource servers ya existen"
                )
        return self

    @model_validator(mode='after')
    def validate_domain_requires_prefix(self):
        if self.enable_domain and not self.domain_prefix and not self.existing_user_pool_id:
            raise ValueError(
                "Si 'enable_domain: true' debe declarar 'domain_prefix'"
            )
        return self

    @model_validator(mode='after')
    def validate_client_credentials_requires_resource_servers(self):
        if self.enable_client_credentials and not self.resource_servers and not self.existing_user_pool_id:
            raise ValueError(
                "Si 'enable_client_credentials: true' debe declarar 'resource_servers' "
                "con al menos un scope"
            )
        return self


#################################################
# VPC LINK
#################################################
class VpcLink(StrictModel):
    enabled:      bool            = False
    nlb_name:     Optional[str]   = None
    nlb_arn:      Optional[str]   = None
    subnet_group: SubnetGroupEnum = SubnetGroupEnum.EC2

    @field_validator('nlb_arn')
    @classmethod
    def validate_nlb_arn(cls, v):
        return validate_arn_or_variable(v, service_hint="NLB")

    @model_validator(mode='after')
    def validate_nlb_source(self):
        if self.enabled and not self.nlb_name and not self.nlb_arn:
            raise ValueError(
                "Si 'vpc_link.enabled: true' debe declarar "
                "'nlb_name' (referencia al ELB del IDP) o 'nlb_arn' (variable del pipeline)"
            )
        return self


#################################################
# STAGE
#################################################
class Stage(StrictModel):
    create:             bool             = True
    logging_level:      LoggingLevelEnum = LoggingLevelEnum.INFO
    enable_metrics:     bool             = True
    enable_data_trace:  bool             = False
    log_retention_days: int              = Field(default=30, ge=1, le=3653)


#################################################
# USAGE PLAN
#################################################
class UsagePlan(StrictModel):
    enable_api_key:       bool            = True
    quota_limit:          int             = Field(default=1000, ge=1)
    quota_period:         QuotaPeriodEnum = QuotaPeriodEnum.MONTH
    throttle_rate_limit:  int             = Field(default=10, ge=0)
    throttle_burst_limit: int             = Field(default=2, ge=0)

    @model_validator(mode='after')
    def validate_burst_vs_rate(self):
        if self.throttle_burst_limit > self.throttle_rate_limit * 2:
            raise ValueError(
                f"'throttle_burst_limit' ({self.throttle_burst_limit}) no puede ser mayor "
                f"al doble de 'throttle_rate_limit' ({self.throttle_rate_limit})"
            )
        return self


#################################################
# CUSTOM DOMAIN
#################################################
class SecurityPolicyEnum(str, Enum):
    TLS_1_0 = "TLS_1_0"
    TLS_1_2 = "TLS_1_2"


class CustomDomain(StrictModel):
    enabled:         bool           = False
    name:            Optional[str]  = None
    existing_name:   Optional[str]  = None   
    certificate_arn: Optional[str]  = None
    base_path:       str            = "(none)"
    security_policy: SecurityPolicyEnum = SecurityPolicyEnum.TLS_1_2

    @field_validator('name', 'existing_name')
    @classmethod
    def validate_domain_name(cls, v):
        if v is None:
            return v
        if not re.match(r'^[a-zA-Z0-9][a-zA-Z0-9\-\.]+[a-zA-Z0-9]$', v):
            raise ValueError(
                f"'{v}' no es un nombre de dominio válido. "
                f"Ejemplo: api.dev.example.com"
            )
        return v

    @field_validator('certificate_arn')
    @classmethod
    def validate_cert_arn(cls, v):
        return validate_arn_or_variable(v, service_hint="certificado ACM")

    @model_validator(mode='after')
    def validate_enabled_requires_fields(self):
        if self.enabled:
            if self.name and self.existing_name:
                raise ValueError(
                    "No puedes declarar 'name' y 'existing_name' al mismo tiempo en 'custom_domain'"
                )
            if not self.name and not self.existing_name:
                raise ValueError(
                    "Si 'custom_domain.enabled: true' debe declarar 'name' o 'existing_name'"
                )
            if self.name and not self.certificate_arn:
                raise ValueError(
                    "Si 'custom_domain.enabled: true' con 'name' debe declarar 'certificate_arn'"
                )
        return self


#################################################
# PATH
#################################################
class Path(StrictModel):
    key:              str
    path_part:        str
    methods:          List[HttpMethodEnum] = []
    parent_key:       Optional[str]        = None
    integration_uri:  Optional[str]        = None
    api_key_required: bool                 = False

    @field_validator('key')
    @classmethod
    def validate_key(cls, v):
        if not re.match(r'^[a-zA-Z0-9_\-]+$', v):
            raise ValueError(
                f"'{v}' no es una key válida. "
                f"Solo se permiten letras, números, guiones y guiones bajos"
            )
        return v

    @field_validator('path_part')
    @classmethod
    def validate_path_part(cls, v):
        if not re.match(r'^(\{proxy\+\}|\{[a-zA-Z0-9_]+\}|[a-zA-Z0-9_\-]+)$', v):
            raise ValueError(
                f"'{v}' no es un path_part válido. "
                f"Ejemplos válidos: 'api', 'v1', '{{proxy+}}', '{{userId}}'"
            )
        return v


    @model_validator(mode='after')
    def validate_proxy_has_methods(self):
        if self.path_part == '{proxy+}' and not self.methods:
            raise ValueError(
                "El path '{proxy+}' debe tener al menos un método en 'methods'. "
                "Ejemplo: methods: ['ANY']"
            )
        return self


#################################################
# ROUTE
#################################################
class Route(StrictModel):
    name:             str
    api_gateway_name: str                               
    authorization:    AuthorizationEnum    = AuthorizationEnum.NONE
    integration_uri:  Optional[str]        = None
    nlb_name:         Optional[str]        = None
    nlb_arn:          Optional[str]        = None
    paths:            List[Path]           = []
    create_proxy:     bool                 = False
    proxy_methods:    List[HttpMethodEnum] = [HttpMethodEnum.ANY]
    proxy_parent_key: Optional[str]        = None
    integration_type: str                  = "HTTP_PROXY"   
    connection_type:  str                  = "VPC_LINK"     
    tags:             Optional[dict]       = {}

    @field_validator('integration_type')
    @classmethod
    def validate_integration_type(cls, v):
        # ADDED
        if v not in _VALID_INTEGRATION_TYPES:
            raise ValueError(
                f"integration_type='{v}' no es válido. "
                f"Valores válidos: {_VALID_INTEGRATION_TYPES}"
            )
        return v

    @field_validator('connection_type')
    @classmethod
    def validate_connection_type(cls, v):
        # ADDED
        if v not in _VALID_CONNECTION_TYPES:
            raise ValueError(
                f"connection_type='{v}' no es válido. "
                f"Valores válidos: {_VALID_CONNECTION_TYPES}"
            )
        return v

    @field_validator('nlb_arn')
    @classmethod
    def validate_nlb_arn(cls, v):
        return validate_arn_or_variable(v, service_hint="NLB")

    @field_validator('integration_uri')
    @classmethod
    def validate_integration_uri(cls, v):
        if v is None:
            return v
        if not re.match(r'^https?://.+$', v) and not re.match(r'^\$\(.+\)$', v):
            raise ValueError(
                f"'{v}' no es una URI válida. "
                f"Debe comenzar con 'http://', 'https://' o usar una variable: $(NOMBRE)"
            )
        return v

    @model_validator(mode='after')
    def validate_paths_or_proxy(self):
        if not self.paths and not self.create_proxy:
            raise ValueError(
                f"La ruta '{self.name}' debe tener 'paths' declarados "
                f"o 'create_proxy: true'"
            )
        return self

    @model_validator(mode='after')
    def validate_path_keys_unique(self):
        if self.paths:
            keys = [p.key for p in self.paths]
            if len(keys) != len(set(keys)):
                raise ValueError(
                    f"La ruta '{self.name}' tiene keys de paths duplicadas. "
                    f"Cada path debe tener una key única"
                )
        return self

    @model_validator(mode='after')
    def validate_parent_keys_exist(self):
        if self.paths:
            keys = {p.key for p in self.paths}
            for path in self.paths:
                if path.parent_key and path.parent_key not in keys:
                    raise ValueError(
                        f"El path '{path.key}' tiene 'parent_key: {path.parent_key}' "
                        f"que no existe en la lista de paths. "
                        f"Keys disponibles: {sorted(keys)}"
                    )
        return self

    @model_validator(mode='after')
    def validate_proxy_parent_key_exists(self):
        if self.create_proxy and self.proxy_parent_key:
            keys = {p.key for p in self.paths}
            if self.proxy_parent_key not in keys:
                raise ValueError(
                    f"'proxy_parent_key: {self.proxy_parent_key}' no existe en paths. "
                    f"Keys disponibles: {sorted(keys)}"
                )
        return self

    @model_validator(mode='after')
    def validate_path_depth(self):
        if not self.paths:
            return self

        keys = {p.key: p for p in self.paths}

        def get_depth(key, visited=None):
            if visited is None:
                visited = set()
            if key in visited:
                raise ValueError(
                    f"Referencia circular detectada en paths — key: '{key}'"
                )
            visited.add(key)
            path = keys.get(key)
            if not path or not path.parent_key:
                return 0
            return 1 + get_depth(path.parent_key, visited)

        for path in self.paths:
            depth = get_depth(path.key)
            if depth > 9:
                raise ValueError(
                    f"El path '{path.key}' supera el nivel máximo de 9. "
                    f"Nivel actual: {depth}"
                )
        return self

    @model_validator(mode='after')
    def validate_integration_uri_or_nlb(self):
        paths_with_methods = [p for p in self.paths if p.methods]
        has_integration    = any(p.integration_uri for p in paths_with_methods)
        if paths_with_methods and not self.integration_uri and not has_integration:
            raise ValueError(
                f"La ruta '{self.name}' tiene paths con métodos pero no tiene "
                f"'integration_uri' declarado en la ruta ni en los paths individuales"
            )
        return self

    @model_validator(mode='after')
    def validate_connection_type_vpc_link_requires_nlb(self):
        if self.connection_type == "VPC_LINK" and self.paths:
            paths_with_methods = [p for p in self.paths if p.methods]
            if paths_with_methods and not self.nlb_name and not self.nlb_arn and not self.integration_uri:
                raise ValueError(
                    f"La ruta '{self.name}' usa connection_type='VPC_LINK' pero no tiene "
                    f"'nlb_name', 'nlb_arn' ni 'integration_uri' declarado"
                )
        return self


#################################################
# API GATEWAY
#################################################
class ApiGateway(StrictModel):
    name:                  str
    existing_api_name:     Optional[str]         = None
    description:           Optional[str]         = None
    endpoint_type:         EndpointTypeEnum       = EndpointTypeEnum.REGIONAL
    vpc_endpoint_ids:      Optional[List[str]]    = []
    enable_dummy_endpoint: bool                   = True
    cloudwatch_role_arn:   Optional[str]          = None
    cognito:               Cognito                = Cognito()
    vpc_link:              VpcLink                = VpcLink()
    stage:                 Stage                  = Stage()
    usage_plan:            UsagePlan              = UsagePlan()
    custom_domain:         CustomDomain           = CustomDomain()
    tags:                  Optional[dict]         = {}

    @field_validator('cloudwatch_role_arn')
    @classmethod
    def validate_cloudwatch_role_arn(cls, v):
        return validate_arn_or_variable(v, service_hint="CloudWatch Role")

    @field_validator('name')
    @classmethod
    def validate_name(cls, v):
        if not re.match(r'^[a-zA-Z0-9\-]+$', v):
            raise ValueError(
                f"'{v}' no es un nombre válido. "
                f"Solo se permiten letras, números y guiones"
            )
        if len(v) < 1 or len(v) > 64:
            raise ValueError("'name' debe tener entre 1 y 64 caracteres")
        return v

    @field_validator('vpc_endpoint_ids')
    @classmethod
    def validate_vpc_endpoint_ids(cls, v):
        if not v:
            return v
        for vpce in v:
            if not vpce.startswith('vpce-'):
                raise ValueError(
                    f"'{vpce}' no es un VPC endpoint ID válido. "
                    f"Debe comenzar con 'vpce-'"
                )
        return v

    @model_validator(mode='after')
    def validate_existing_api(self):
        if self.existing_api_name and self.vpc_endpoint_ids:
            raise ValueError(
                "No se puede declarar 'vpc_endpoint_ids' si se usa un "
                "API Gateway existente"
            )
        return self

    @model_validator(mode='after')
    def validate_private_requires_vpc_endpoints(self):
        if (self.endpoint_type == EndpointTypeEnum.PRIVATE
                and not self.vpc_endpoint_ids
                and not self.existing_api_name):
            raise ValueError(
                "Si 'endpoint_type: PRIVATE' debe declarar 'vpc_endpoint_ids' "
                "con al menos un VPC endpoint ID"
            )
        return self




#################################################
# NETWORKING
#################################################
class Networking(StrictModel):
    depends_on:          List[str]                  = []
    elbs:                Optional[List[ELB]]        = None
    eni_interfaces:      Optional[List[ENI]]        = None
    namespaces:          Optional[List[Namespace]]  = None
    api_gateways:        Optional[List[ApiGateway]] = None
    api_gateway_routes:  Optional[List[Route]]      = None   

    @model_validator(mode='after')
    def validate_eni_names(self):
        if self.eni_interfaces:
            names = [e.name for e in self.eni_interfaces]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de eni_interfaces deben ser únicos")
        return self

    @model_validator(mode='after')
    def validate_elb_names(self):
        if self.elbs:
            names = [e.name for e in self.elbs]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de ELBs deben ser únicos")
        return self

    @model_validator(mode='after')
    def validate_namespace_names(self):
        if self.namespaces:
            names = [n.name for n in self.namespaces]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de namespaces deben ser únicos")
        return self

    @model_validator(mode='after')
    def validate_api_gateway_names_unique(self):
        if self.api_gateways:
            names = [a.name for a in self.api_gateways]
            if len(names) != len(set(names)):
                raise ValueError(
                    "Los nombres de api_gateways deben ser únicos dentro del proyecto"
                )
        return self

    @model_validator(mode='after')
    def validate_route_names_unique(self):
        if self.api_gateway_routes:
            names = [r.name for r in self.api_gateway_routes]
            if len(names) != len(set(names)):
                raise ValueError("Los nombres de api_gateway_routes deben ser únicos")
        return self

    @model_validator(mode='after')
    def validate_route_api_gateway_references(self):
        if self.api_gateway_routes and self.api_gateways:
            gw_names = {gw.name for gw in self.api_gateways}
            for route in self.api_gateway_routes:
                if route.api_gateway_name not in gw_names:
                    raise ValueError(
                        f"api_gateway_routes '{route.name}': "
                        f"'api_gateway_name: {route.api_gateway_name}' "
                        f"no existe en api_gateways. "
                        f"Disponibles: {sorted(gw_names)}"
                    )
        return self

    @model_validator(mode='after')
    def validate_cognito_and_vpc_link_per_route(self):
        if not self.api_gateway_routes or not self.api_gateways:
            return self
        gw_map = {gw.name: gw for gw in self.api_gateways}
        for route in self.api_gateway_routes:
            gw = gw_map.get(route.api_gateway_name)
            if not gw:
                continue
            
            if (route.authorization == AuthorizationEnum.COGNITO_USER_POOLS
                    and not gw.cognito.enabled):
                raise ValueError(
                    f"api_gateway_routes '{route.name}': usa "
                    f"'authorization: COGNITO_USER_POOLS' pero "
                    f"'cognito.enabled' es false en api_gateway '{gw.name}'"
                )
            
            paths_with_methods = [p for p in route.paths if p.methods]
            if paths_with_methods and not gw.vpc_link.enabled and route.connection_type == "VPC_LINK":
                raise ValueError(
                    f"api_gateway_routes '{route.name}': tiene paths con métodos y "
                    f"connection_type='VPC_LINK' pero 'vpc_link.enabled' es false "
                    f"en api_gateway '{gw.name}'"
                )
        return self