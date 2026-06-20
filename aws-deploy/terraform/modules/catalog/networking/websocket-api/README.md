# Módulo WebSocket API

Crea o referencia un WebSocket API en Amazon API Gateway v2 con soporte para VPC Link, rutas y stage. Permite exponer servicios internos via WebSocket usando el mismo patrón del módulo REST API.

El módulo está dividido en dos componentes:
- **`websocket_apis`** — Infraestructura base: API, VPC Link v2, stage
- **`websocket_routes`** — Rutas y sus integraciones con el backend

---

## Uso en config.yml

```yaml
catalog:
  networking:
    websocket_apis:
      - name: ws-api        # REQUERIDO

    websocket_routes:
      - name: ws-routes     # REQUERIDO
        api_name: ws-api
        integration_uri: "http://nlb-dns"
        routes:
          - key: connect
            route_key: "$connect"
          - key: default
            route_key: "$default"
```

---

## Parámetros — `websocket_apis`

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre lógico del WebSocket API |

> `project_name`, `environment`, `vpc_id` y `subnet_ids` los inyecta el engine automáticamente.

---

### API

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create` | bool | `true` | `true` \| `false` | `true` = crea el API, `false` = referencia uno existente |
| `existing_api_name` | string | `null` | Nombre del API o `null` | Busca el WebSocket API por nombre en AWS. Requerido si `create: false` |
| `description` | string | `null` | Cualquier string | Descripción del API |
| `route_selection_expression` | string | `$request.body.action` | Expresión válida | Cómo selecciona la ruta según el mensaje recibido |

---

### Stage

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create_stage` | bool | `true` | `true` \| `false` | Crear el stage del API |
| `auto_deploy` | bool | `true` | `true` \| `false` | Desplegar automáticamente cuando hay cambios |
| `log_retention_days` | number | `30` | `1` \| `7` \| `14` \| `30` \| `60` \| `90` \| `180` \| `365` | Días de retención de logs en CloudWatch |

---

### VPC Link

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `vpc_link.enabled` | bool | `false` | `true` \| `false` | Crear VPC Link v2 para integración con NLB interno |
| `vpc_link.nlb_name` | string | `null` | Nombre del NLB o `null` | NLB destino. El engine resuelve el ARN automáticamente |
| `vpc_link.nlb_arn` | string | `null` | ARN de NLB o `null` | ARN directo del NLB. Alternativa a `nlb_name` |
| `vpc_link.subnet_group` | string | `EC2` | `EC2` \| `ELB` | Grupo de subnets para el VPC Link |

---

### Security Group

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `ingress_cidr` | string | `10.0.0.0/8` | CIDR válido | Rango de IPs permitido en el SG del VPC Link |
| `ingress_port` | number | `443` | `1` - `65535` | Puerto de ingress del SG del VPC Link |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Parámetros — `websocket_routes`

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre lógico del grupo de rutas |
| `api_name` | string | Nombre del WebSocket API base |
| `integration_uri` | string | URI del backend. Ej: `http://nlb-dns` |

> `api_id` y `vpc_link_id` los resuelve el engine automáticamente desde el API base.

---

### Integración

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `integration_type` | string | `HTTP_PROXY` | `HTTP_PROXY` \| `AWS_PROXY` | Tipo de integración con el backend |
| `connection_type` | string | `VPC_LINK` | `VPC_LINK` \| `INTERNET` | Tipo de conexión |
| `integration_method` | string | `ANY` | `GET` \| `POST` \| `ANY` | Método HTTP de la integración |

---

### Rutas

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `routes` | list | `[]` | Ver estructura abajo | Rutas WebSocket a crear |

#### Estructura de `routes`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `key` | string | — | Cualquier string | Identificador único de la ruta — **REQUERIDO** |
| `route_key` | string | — | Ver tabla abajo | Clave de la ruta WebSocket — **REQUERIDO** |
| `integration_uri` | string | `null` | URI o `null` | URI específica para esta ruta. `null` = hereda la del módulo |
| `authorization_type` | string | `NONE` | `NONE` \| `JWT` \| `AWS_IAM` \| `CUSTOM` | Tipo de autorización |

#### Rutas especiales de WebSocket

| `route_key` | Cuándo se dispara | Uso típico |
|-------------|------------------|-----------|
| `$connect` | Cliente se conecta | Autenticación, registro de conexión |
| `$disconnect` | Cliente se desconecta | Limpieza de recursos |
| `$default` | Mensaje sin ruta coincidente | Catch-all |
| `action/send` | Mensaje con `{"action":"send"}` | Rutas custom |
| `action/chat` | Mensaje con `{"action":"chat"}` | Rutas custom |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Ejemplos

### WebSocket nuevo con VPC Link

```yaml
networking:
  elbs:
    - name: internal-nlb
      load_balancer_type: network
      internal: true
      port: 80

  websocket_apis:
    - name: ws-api
      create: true
      vpc_link:
        enabled: true
        nlb_name: internal-nlb

  websocket_routes:
    - name: ws-routes
      api_name: ws-api
      integration_uri: "http://nlb-dns"
      routes:
        - key: connect
          route_key: "$connect"
        - key: disconnect
          route_key: "$disconnect"
        - key: default
          route_key: "$default"
```

---

### WebSocket existente — solo VPC Link y rutas

```yaml
networking:
  elbs:
    - name: internal-nlb
      load_balancer_type: network
      internal: true
      port: 80

  websocket_apis:
    - name: ws-existing
      create: false                              # ← No crea el API
      existing_api_name: mi-websocket-api        # ← Busca por nombre
      create_stage: false                        # ← No crea el stage
      vpc_link:
        enabled: true                            # ← Solo crea el VPC Link
        nlb_name: internal-nlb

  websocket_routes:
    - name: ws-routes
      api_name: ws-existing
      connection_type: VPC_LINK
      integration_uri: "http://nlb-dns"
      routes:
        - key: connect
          route_key: "$connect"
        - key: disconnect
          route_key: "$disconnect"
        - key: default
          route_key: "$default"
```

---

### WebSocket con rutas custom por acción

```yaml
networking:
  websocket_apis:
    - name: ws-api
      create: true
      route_selection_expression: "$request.body.action"
      vpc_link:
        enabled: true
        nlb_name: internal-nlb

  websocket_routes:
    - name: ws-routes
      api_name: ws-api
      connection_type: VPC_LINK
      integration_uri: "http://nlb-dns"
      routes:
        - key: connect
          route_key: "$connect"
        - key: disconnect
          route_key: "$disconnect"

        # Rutas custom según action en el mensaje
        - key: send
          route_key: "action/send"
          integration_uri: "http://nlb-dns/send"    # URI específica

        - key: subscribe
          route_key: "action/subscribe"

        - key: default
          route_key: "$default"
```

---

### Completo con todas las opciones

```yaml
networking:
  websocket_apis:
    - name: ws-api

      # API
      create: true
      description: "WebSocket API para comunicación en tiempo real"
      route_selection_expression: "$request.body.action"

      # Stage
      create_stage: true
      auto_deploy: true
      log_retention_days: 30

      # VPC Link
      vpc_link:
        enabled: true
        nlb_name: internal-nlb
        subnet_group: EC2

      # Security Group
      ingress_cidr: "10.0.0.0/8"
      ingress_port: 443

      tags:
        team: platform
        component: websocket

  websocket_routes:
    - name: ws-routes

      # API base
      api_name: ws-api
      integration_uri: "http://nlb-dns"

      # Integración
      integration_type: HTTP_PROXY
      connection_type: VPC_LINK
      integration_method: ANY

      # Rutas
      routes:
        - key: connect
          route_key: "$connect"
        - key: disconnect
          route_key: "$disconnect"
        - key: send
          route_key: "action/send"
        - key: default
          route_key: "$default"

      tags:
        team: platform
```

---

## Diferencias REST API vs WebSocket API

| Aspecto | REST API | WebSocket API |
|---------|---------|---------------|
| Protocolo | HTTP/HTTPS | WSS (WebSocket Secure) |
| Conexión | Sin estado — una request = una response | Con estado — conexión persistente |
| Rutas | Jerárquicas `/api/v1/users` | Planas `$connect`, `action/send` |
| VPC Link | v1 (solo NLB) | v2 (NLB o ALB) |
| Deployment | Manual trigger | Auto deploy |
| URL cliente | `https://api-id.execute-api.region.amazonaws.com/stage` | `wss://api-id.execute-api.region.amazonaws.com/stage` |

---

## Flujo de conexión WebSocket

```
Cliente → wss://api-id.execute-api.us-east-1.amazonaws.com/dev
                ↓
         $connect route
                ↓
         VPC Link v2
                ↓
         NLB → ECS Service (backend registra la conexión)
                ↓
         Cliente envía { "action": "send", "data": "..." }
                ↓
         action/send route → NLB → ECS Service
                ↓
         ECS Service puede enviar mensajes de vuelta al cliente
         via API Gateway Management API
```

---

## Restricciones

- `existing_api_name` requerido cuando `create: false`
- `vpc_link.nlb_name` o `vpc_link.nlb_arn` requerido cuando `vpc_link.enabled: true`
- `route_selection_expression` debe coincidir con el campo del mensaje JSON que selecciona la ruta
- Las rutas `$connect`, `$disconnect` y `$default` son especiales — se recomienda siempre declararlas
- `create_stage: false` cuando el WebSocket es existente y ya tiene stage

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| WebSocket API | `wsapi-{project_name}-{name}` | `wsapi-mi-proyecto-tf-ws-api` |
| VPC Link | `vpc-link-{project_name}-{name}` | `vpc-link-mi-proyecto-tf-ws-api` |
| Security Group | `secg-{project_name}-{name}-ws-vpc-link` | `secg-mi-proyecto-tf-ws-api-ws-vpc-link` |
| Log Group | `/aws/apigateway/websocket/{project_name}/{environment}/{name}` | `/aws/apigateway/websocket/mi-proyecto-tf/dev/ws-api` |
