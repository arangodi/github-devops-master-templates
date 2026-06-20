# Módulo API Gateway

Crea un REST API Gateway con soporte para Cognito, VPC Link, custom domain, API Keys y rutas hacia servicios internos via NLB o endpoints públicos via Internet.

El módulo está dividido en dos componentes que trabajan juntos:
- **`api-gateways/base`** — Crea la infraestructura base: API, stage, Cognito, VPC Link, usage plan
- **`api-gateway/routes`** — Crea los paths y métodos HTTP que apuntan al backend

---

## Uso en config.yml

```yaml
catalog:
  networking:
    api_gateways:
      - name: public       # REQUERIDO

    api_gateway_routes:
      - name: backend      # REQUERIDO
        api_gateway_name: public
        integration_uri: "http://${nlb_dns}/backend"
        nlb_name: internal-nlb
```

---

## Parámetros — `api_gateways`

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre lógico del API Gateway |

> `project_name`, `environment`, `vpc_id` y `subnet_ids` los inyecta el engine automáticamente.

---

### API

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `description` | string | `null` | Cualquier string | Descripción del API |
| `endpoint_type` | string | `REGIONAL` | `REGIONAL` \| `EDGE` \| `PRIVATE` | Tipo de endpoint |
| `existing_api_name` | string | `null` | Nombre de API o `null` | Referencia un API existente. El engine obtiene el ID automáticamente |
| `enable_dummy_endpoint` | bool | `true` | `true` \| `false` | Crea endpoint `/ping` para el deployment inicial |
| `vpc_endpoint_ids` | list(string) | `[]` | Lista de VPC endpoint IDs | Solo si `endpoint_type: PRIVATE` |

---

### Stage y logs

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create_stage` | bool | `true` | `true` \| `false` | Crear el stage del API |
| `logging_level` | string | `INFO` | `OFF` \| `ERROR` \| `INFO` | Nivel de logging en CloudWatch |
| `enable_method_metrics` | bool | `true` | `true` \| `false` | Métricas por método en CloudWatch |
| `enable_data_trace` | bool | `false` | `true` \| `false` | Traza completa de request/response. Solo para debugging |
| `log_retention_days` | number | `30` | `1` \| `7` \| `14` \| `30` \| `60` \| `90` \| `180` \| `365` | Días de retención en CloudWatch |
| `cloudwatch_role_arn` | string | `null` | ARN de IAM role o `null` | Role para escribir logs. `null` = sin logs |

---

### Cognito

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `enable_cognito` | bool | `false` | `true` \| `false` | Crear Cognito User Pool y autorizador |
| `client_name` | string | `null` | Cualquier string | Nombre del cliente OAuth2 |
| `existing_user_pool_id` | string | `null` | ID de User Pool o `null` | Usa un User Pool existente. Si se declara no crea uno nuevo |
| `enable_cognito_domain` | bool | `false` | `true` \| `false` | Crear dominio para el User Pool |
| `cognito_domain_prefix` | string | `""` | Cualquier string único | Prefijo del dominio de Cognito |
| `access_token_validity` | number | `60` | `1` - `1440` minutos | Duración del access token |
| `id_token_validity` | number | `60` | `1` - `1440` minutos | Duración del ID token |
| `refresh_token_validity` | number | `30` | `1` - `3650` días | Duración del refresh token |
| `enable_token_revocation` | bool | `true` | `true` \| `false` | Permitir revocar tokens |
| `enable_client_credentials` | bool | `false` | `true` \| `false` | Flujo M2M (machine-to-machine) |
| `resource_servers` | list | `[]` | Ver estructura abajo | Resource servers para flujo M2M |

#### Estructura de `resource_servers`

| Campo | Tipo | Valores aceptados | Descripción |
|-------|------|-------------------|-------------|
| `identifier` | string | URL o URN | Identificador único del resource server — **REQUERIDO** |
| `name` | string | Cualquier string | Nombre del resource server — **REQUERIDO** |
| `scopes` | list | Ver estructura abajo | Scopes del resource server — **REQUERIDO** |

#### Estructura de `scopes`

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre del scope — **REQUERIDO** |
| `description` | string | Descripción del scope — **REQUERIDO** |

```yaml
resource_servers:
  - identifier: https://api.mi-proyecto.com
    name: mi-api
    scopes:
      - name: read
        description: "Acceso de lectura"
      - name: write
        description: "Acceso de escritura"
```

---

### VPC Link

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `enable_vpc_link` | bool | `false` | `true` \| `false` | Crear VPC Link para integración con NLB interno |
| `nlb_arn` | string | `null` | ARN de NLB o `null` | NLB destino del VPC Link. Requerido si `enable_vpc_link: true` |

---

### API Key y usage plan

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `enable_api_key` | bool | `true` | `true` \| `false` | Crear API Key y Usage Plan |
| `quota_limit` | number | `1000` | Número ≥ 1 | Requests máximos por periodo |
| `quota_period` | string | `MONTH` | `DAY` \| `WEEK` \| `MONTH` | Periodo del quota |
| `throttle_rate_limit` | number | `10` | Número ≥ 0 | Requests por segundo (rate) |
| `throttle_burst_limit` | number | `2` | Número ≥ 0 | Pico máximo de requests (burst) |

---

### Custom domain

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `enable_custom_domain` | bool | `false` | `true` \| `false` | Habilitar custom domain |
| `custom_domain_name` | string | `""` | FQDN | Nombre del dominio. Ej: `api.btgpactual.com.co` |
| `custom_domain_base_path` | string | `(none)` | Cualquier path | Base path del mapping. `(none)` = raíz |
| `custom_domain_certificate_arn` | string | `null` | ARN de ACM o `null` | Certificado ACM para el dominio. Requerido si `enable_custom_domain: true` |
| `custom_domain_security_policy` | string | `TLS_1_2` | `TLS_1_0` \| `TLS_1_2` | Política TLS del dominio |
| `existing_custom_domain_name` | string | `null` | FQDN o `null` | Referencia un custom domain existente sin crear uno nuevo |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Parámetros — `api_gateway_routes`

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre lógico del grupo de rutas |
| `api_gateway_name` | string | Nombre del API Gateway base donde se crean las rutas |

> `apigw_id`, `apigw_root_resource_id`, `apigw_stage_name`, `vpc_link_id` y `authorizer_id` los resuelve el engine automáticamente desde el API Gateway base.

---

### Rutas

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `paths` | list | `[]` | Ver estructura abajo | Paths y métodos HTTP a crear |
| `create_proxy` | bool | `false` | `true` \| `false` | Crear recurso `{proxy+}` directamente bajo la raíz |
| `proxy_methods` | list(string) | `[ANY]` | Lista de métodos HTTP | Métodos del proxy |
| `proxy_parent_key` | string | `null` | Key de un path o `null` | Padre del `{proxy+}`. `null` = raíz del API |

#### Estructura de `paths`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `key` | string | — | Cualquier string | Identificador único del path — **REQUERIDO** |
| `path_part` | string | — | Segmento de URL | Segmento de la ruta. Ej: `api`, `v1`, `{proxy+}` — **REQUERIDO** |
| `methods` | list(string) | — | `GET` \| `POST` \| `PUT` \| `DELETE` \| `PATCH` \| `ANY` \| `[]` | Métodos HTTP. `[]` = solo crea el recurso sin métodos — **REQUERIDO** |
| `parent_key` | string | — | Key de otro path o `null` | Key del path padre. `null` = raíz del API — **REQUERIDO** |
| `integration_uri` | string | `null` | URI, URI especial o `null` | URI de integración específica para este path. `null` = hereda la del módulo |
| `api_key_required` | bool | `false` | `true` \| `false` | Requerir API Key para este path |

---

### Integración

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `integration_uri` | string | `null` | URI o URI especial | URI del backend. Puede ser una URL o un valor especial (ver abajo) |
| `authorization` | string | `NONE` | `NONE` \| `COGNITO_USER_POOLS` | Tipo de autorización para las rutas |
| `integration_type` | string | `HTTP_PROXY` | `HTTP_PROXY` \| `HTTP` \| `AWS_PROXY` \| `MOCK` | Tipo de integración con el backend |
| `connection_type` | string | `VPC_LINK` | `VPC_LINK` \| `INTERNET` | Tipo de conexión. `VPC_LINK` para backends internos, `INTERNET` para endpoints públicos |
| `nlb_name` | string | `null` | Nombre del NLB o `null` | NLB para el VPC Link. Requerido si `connection_type: VPC_LINK` |
| `http_method` | string | `ANY` | `GET` \| `POST` \| `PUT` \| `DELETE` \| `ANY` | Método HTTP del método de API Gateway |
| `integration_http_method` | string | `ANY` | `GET` \| `POST` \| `PUT` \| `DELETE` \| `ANY` | Método HTTP de la integración con el backend |

---

### URIs especiales de Cognito

Cuando `connection_type: INTERNET`, puedes usar estos valores en `integration_uri` para apuntar automáticamente a los endpoints de Cognito sin escribir la URL completa:

| Valor | Endpoint Cognito | Método típico |
|-------|-----------------|---------------|
| `COGNITO_TOKEN` | `/oauth2/token` | `POST` |
| `COGNITO_AUTHORIZE` | `/oauth2/authorize` | `GET` |
| `COGNITO_USERINFO` | `/oauth2/userInfo` | `GET` |
| `COGNITO_REVOKE` | `/oauth2/revoke` | `POST` |

> ℹ️ El engine resuelve automáticamente estos valores a la URL real del User Pool de Cognito. Solo funcionan cuando el API Gateway tiene `enable_cognito: true`.

---

## Ejemplos

### API interna con VPC Link (patrón más común)

```yaml
networking:
  elbs:
    - name: internal-nlb
      load_balancer_type: network
      internal: true
      port: 80

  api_gateways:
    - name: public
      enable_vpc_link: true
      nlb_name: internal-nlb

  api_gateway_routes:
    - name: backend
      api_gateway_name: public
      nlb_name: internal-nlb
      integration_uri: "http://nlb-dns/api"
      connection_type: VPC_LINK
      authorization: NONE
      paths:
        - key: api
          path_part: api
          methods: []
          parent_key: null
        - key: proxy
          path_part: "{proxy+}"
          methods: ["ANY"]
          parent_key: api
```

---

### API con endpoints de Cognito expuestos

```yaml
networking:
  api_gateways:
    - name: public
      enable_cognito: true
      client_name: mi-app
      enable_cognito_domain: true
      cognito_domain_prefix: mi-app-dev
      enable_client_credentials: true
      resource_servers:
        - identifier: api-mi-proyecto
          name: mi-proyecto
          scopes:
            - name: read
              description: "Lectura"
            - name: write
              description: "Escritura"

  api_gateway_routes:
    # Rutas OAuth expuestas via Internet
    - name: oauth-endpoints
      api_gateway_name: public
      integration_type: HTTP_PROXY
      connection_type: INTERNET
      paths:
        - key: oauth
          path_part: oauth
          methods: []
          parent_key: null

        - key: oauth-token
          path_part: token
          methods: ["POST"]
          parent_key: oauth
          integration_uri: COGNITO_TOKEN       # ← URI especial

        - key: oauth-authorize
          path_part: authorize
          methods: ["GET"]
          parent_key: oauth
          integration_uri: COGNITO_AUTHORIZE   # ← URI especial

        - key: oauth-userinfo
          path_part: userInfo
          methods: ["GET"]
          parent_key: oauth
          integration_uri: COGNITO_USERINFO    # ← URI especial

        - key: oauth-revoke
          path_part: revoke
          methods: ["POST"]
          parent_key: oauth
          integration_uri: COGNITO_REVOKE      # ← URI especial
```

---

### API con Cognito nuevo y rutas internas + OAuth

```yaml
networking:
  api_gateways:
    - name: public
      endpoint_type: REGIONAL
      enable_dummy_endpoint: true
      enable_cognito: true
      client_name: onboarding-app
      enable_cognito_domain: true
      cognito_domain_prefix: onboarding-app-dev
      enable_client_credentials: true
      access_token_validity: 60
      refresh_token_validity: 1
      resource_servers:
        - identifier: api-onboarding
          name: onboarding
          scopes:
            - name: read
              description: "Read access"
            - name: write
              description: "Write access"
      enable_vpc_link: true
      nlb_name: internal-nlb
      custom_domain:
        enabled: true
        existing_name: rapigwdev.btgpactual.com.co
        base_path: onboarding

  api_gateway_routes:
    # Endpoints OAuth públicos
    - name: oauth-endpoints
      api_gateway_name: public
      integration_type: HTTP_PROXY
      connection_type: INTERNET
      paths:
        - key: oauth
          path_part: oauth
          methods: []
          parent_key: null
        - key: oauth-token
          path_part: token
          methods: ["POST"]
          parent_key: oauth
          integration_uri: COGNITO_TOKEN

    # API interna via VPC Link
    - name: api-routes
      api_gateway_name: public
      nlb_name: internal-nlb
      integration_uri: "http://nlb-dns/api"
      connection_type: VPC_LINK
      authorization: COGNITO_USER_POOLS
      paths:
        - key: api
          path_part: api
          methods: []
          parent_key: null
        - key: api-proxy
          path_part: "{proxy+}"
          methods: ["ANY"]
          parent_key: api
```

---

### API con custom domain existente

```yaml
networking:
  api_gateways:
    - name: public
      endpoint_type: REGIONAL
      custom_domain:
        enabled: true
        existing_name: rapigwdev.btgpactual.com.co
        base_path: mi-servicio
```

---

### API con Cognito existente

```yaml
networking:
  api_gateways:
    - name: public
      enable_cognito: true
      existing_user_pool_id: us-east-1_ABC123
      client_name: mi-app
      enable_vpc_link: true
      nlb_name: internal-nlb
```

---

### API con múltiples rutas hacia distintos servicios

```yaml
networking:
  api_gateway_routes:
    - name: servicios
      api_gateway_name: public
      nlb_name: internal-nlb
      integration_uri: "http://nlb-dns"
      connection_type: VPC_LINK
      authorization: COGNITO_USER_POOLS
      paths:
        - key: v1
          path_part: v1
          methods: []
          parent_key: null

        - key: users
          path_part: users
          methods: []
          parent_key: v1

        - key: users-proxy
          path_part: "{proxy+}"
          methods: ["ANY"]
          parent_key: users

        - key: orders
          path_part: orders
          methods: []
          parent_key: v1

        - key: orders-proxy
          path_part: "{proxy+}"
          methods: ["ANY"]
          parent_key: orders
```

---

## Dos tipos de conexión

| `connection_type` | Cuándo usar | `nlb_name` | `integration_uri` |
|-------------------|-------------|------------|-------------------|
| `VPC_LINK` | Backend interno en VPC (ECS, EC2) | Requerido | URL del NLB |
| `INTERNET` | Endpoint público (Cognito, externos) | No aplica | URL pública o valor especial |

---

## Flujo de autenticación con Cognito

```
Cliente → POST /oauth/token (INTERNET → Cognito)
              ↓
        Obtiene JWT token
              ↓
Cliente → GET /api/resource (VPC_LINK)
              ↓
        API Gateway valida JWT con Cognito
              ↓
        ✅ Válido → NLB → ECS Service
        ❌ Inválido → 401 Unauthorized
```

---

## Restricciones

- `authorization: COGNITO_USER_POOLS` requiere `enable_cognito: true`
- `connection_type: VPC_LINK` requiere `nlb_name`
- `connection_type: INTERNET` no requiere `nlb_name`
- URIs especiales (`COGNITO_TOKEN`, etc.) solo funcionan con `enable_cognito: true`
- `enable_client_credentials: true` requiere al menos un `resource_server`
- `enable_custom_domain: true` requiere `custom_domain_certificate_arn`
- `existing_user_pool_id` y `cognito_domain_prefix` son mutuamente excluyentes
- `endpoint_type: PRIVATE` requiere `vpc_endpoint_ids`
- `endpoint_type: PRIVATE` crea automáticamente una resource policy que permite `execute-api:Invoke` solo desde los VPC endpoints declarados
- `{proxy+}` captura todos los sub-paths

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| API Gateway | `apigw-{project_name}-{name}` | `apigw-mi-proyecto-tf-public` |
| VPC Link | `vpc-link-{project_name}-{name}` | `vpc-link-mi-proyecto-tf-public` |
| Cognito User Pool | `{project_name}-{name}-user-pool` | `mi-proyecto-tf-public-user-pool` |
| Cognito Client | `{project_name}-{client_name}-client` | `mi-proyecto-tf-mi-app-client` |
| API Key | `{project_name}-{name}-api-key` | `mi-proyecto-tf-public-api-key` |