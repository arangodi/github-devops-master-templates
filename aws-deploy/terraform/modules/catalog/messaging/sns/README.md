# Módulo SNS

Crea topics SNS estándar o FIFO con soporte para suscripciones, filtros de mensajes y políticas de acceso.

---

## Uso en config.yml

```yaml
catalog:
  messaging:
    sns_topics:
      - name: events    # REQUERIDO
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre del topic |

> `project_name`, `environment` y `account` los inyecta el engine automáticamente.

---

### Topic

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `fifo` | bool | `false` | `true` \| `false` | Crea un topic FIFO. Los topics FIFO solo pueden suscribirse a colas SQS FIFO |
| `content_based_deduplication` | bool | `false` | `true` \| `false` | Deduplicación automática basada en el contenido. Solo para topics FIFO |
| `kms_master_key_id` | string | `null` | ID de KMS key o `null` | Encripción de mensajes. `null` = sin encripción |

---

### Suscripciones

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `subscriptions` | list | `[]` | Ver estructura abajo | Suscriptores del topic |

#### Estructura de `subscriptions`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `protocol` | string | — | `sqs` \| `lambda` \| `http` \| `https` \| `email` \| `sms` | Protocolo de entrega — **REQUERIDO** |
| `endpoint` | string | — | ARN o URL según protocolo | Destino del mensaje — **REQUERIDO** |
| `filter_policy` | string | `null` | JSON string o `null` | Filtro de mensajes en formato JSON. `null` = recibe todos |
| `filter_policy_scope` | string | `null` | `MessageAttributes` \| `MessageBody` \| `null` | Dónde aplica el filtro |
| `raw_message_delivery` | bool | `false` | `true` \| `false` | Entrega el mensaje sin el envelope de SNS. Solo para SQS y HTTP/S |
| `redrive_policy` | string | `null` | JSON string o `null` | Dead letter queue para mensajes fallidos |

```yaml
subscriptions:
  - protocol: sqs
    endpoint: arn:aws:sqs:us-east-1:123456789:mi-cola.fifo
    filter_policy: '{"eventName": ["order.created"]}'
    filter_policy_scope: MessageBody
    raw_message_delivery: false
```

---

### Políticas de acceso

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `policy_statements` | list | `[]` | Ver estructura abajo | Statements IAM para la política del topic |

#### Estructura de `policy_statements`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `effect` | string | — | `Allow` \| `Deny` | Efecto del statement — **REQUERIDO** |
| `actions` | list(string) | — | Lista de acciones SNS | Acciones permitidas o denegadas — **REQUERIDO** |
| `principals` | list | — | Ver estructura abajo | Principals a los que aplica — **REQUERIDO** |
| `sid` | string | `null` | Cualquier string | Identificador del statement |
| `resources` | list(string) | `null` | Lista de ARNs | `null` = usa el ARN del topic automáticamente |
| `conditions` | list | `[]` | Ver estructura abajo | Condiciones del statement |

#### Estructura de `principals`

| Campo | Tipo | Valores aceptados | Descripción |
|-------|------|-------------------|-------------|
| `type` | string | `AWS` \| `Service` \| `*` | Tipo de principal |
| `identifiers` | list(string) | Lista de ARNs o servicios | Identidades |

#### Estructura de `conditions`

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `test` | string | Operador de condición. Ej: `StringEquals`, `ArnLike` |
| `variable` | string | Variable de condición. Ej: `aws:SourceAccount` |
| `values` | list(string) | Valores a comparar |

```yaml
policy_statements:
  - sid: AllowSQSPublish
    effect: Allow
    actions:
      - sns:Publish
    principals:
      - type: Service
        identifiers:
          - sqs.amazonaws.com
    conditions:
      - test: ArnLike
        variable: aws:SourceArn
        values:
          - arn:aws:sqs:us-east-1:123456789:mi-cola.fifo
```

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Ejemplos

### Topic estándar simple

```yaml
messaging:
  sns_topics:
    - name: notifications
```

---

### Topic FIFO

```yaml
messaging:
  sns_topics:
    - name: events
      fifo: true
      content_based_deduplication: true
```

---

### Topic con suscripción a SQS

```yaml
messaging:
  sns_topics:
    - name: events
      fifo: true
      subscriptions:
        - protocol: sqs
          endpoint: arn:aws:sqs:us-east-1:123456789:mi-cola.fifo
          raw_message_delivery: false
```

---

### Topic con filtros por tipo de evento

```yaml
messaging:
  sns_topics:
    - name: events
      fifo: true
      subscriptions:
        # Cola 1 — solo eventos de órdenes creadas
        - protocol: sqs
          endpoint: arn:aws:sqs:us-east-1:123456789:orders.fifo
          filter_policy: '{"eventName": ["order.created", "order.updated"]}'
          filter_policy_scope: MessageBody

        # Cola 2 — solo eventos de pagos
        - protocol: sqs
          endpoint: arn:aws:sqs:us-east-1:123456789:payments.fifo
          filter_policy: '{"eventName": [{"prefix": "payment."}]}'
          filter_policy_scope: MessageBody

        # Cola 3 — todos los eventos (sin filtro)
        - protocol: sqs
          endpoint: arn:aws:sqs:us-east-1:123456789:audit.fifo
          raw_message_delivery: false
```

---

### Topic con suscripción a Lambda

```yaml
messaging:
  sns_topics:
    - name: alerts
      subscriptions:
        - protocol: lambda
          endpoint: arn:aws:lambda:us-east-1:123456789:function:process-alert
```

---

### Topic con política de acceso

```yaml
messaging:
  sns_topics:
    - name: events
      fifo: true
      policy_statements:
        - sid: AllowPublishFromAccount
          effect: Allow
          actions:
            - sns:Publish
          principals:
            - type: AWS
              identifiers:
                - arn:aws:iam::123456789:root
```

---

### Topic con encripción KMS

```yaml
messaging:
  sns_topics:
    - name: sensitive-events
      kms_master_key_id: alias/aws/sns
```

---

### Completo con todas las opciones

```yaml
messaging:
  sns_topics:
    - name: events

      # Topic
      fifo: true
      content_based_deduplication: true
      kms_master_key_id: null

      # Suscripciones
      subscriptions:
        - protocol: sqs
          endpoint: arn:aws:sqs:us-east-1:123456789:orders.fifo
          filter_policy: '{"eventName": ["order.created"]}'
          filter_policy_scope: MessageBody
          raw_message_delivery: false
          redrive_policy: null

      # Políticas
      policy_statements:
        - sid: AllowPublish
          effect: Allow
          actions:
            - sns:Publish
          principals:
            - type: AWS
              identifiers:
                - arn:aws:iam::123456789:root
          conditions:
            - test: StringEquals
              variable: aws:RequestedRegion
              values:
                - us-east-1

      # Tags
      tags:
        team: backend
        component: messaging
```

---

## Integración con SQS

El patrón más común es fan-out: un topic SNS distribuye mensajes a múltiples colas SQS con filtros diferentes.

```yaml
messaging:
  sns_topics:
    - name: events
      fifo: true
      subscriptions:
        - protocol: sqs
          endpoint: arn:aws:sqs:...:etl.fifo
          filter_policy: '{"eventName": [{"prefix": "sheet."}]}'
          filter_policy_scope: MessageBody

        - protocol: sqs
          endpoint: arn:aws:sqs:...:audit.fifo

  sqs_queues:
    - name: etl
      fifo: true
    - name: audit
      fifo: true
```

> ℹ️ Cuando usas el engine del IDP, los endpoints de SQS se resuelven automáticamente por nombre sin necesidad de poner el ARN completo.

---

## Restricciones

- Topics FIFO solo pueden entregar a colas SQS FIFO
- `content_based_deduplication: true` solo aplica para topics FIFO
- `filter_policy_scope: MessageBody` requiere que el mensaje sea JSON válido
- `raw_message_delivery: true` solo aplica para suscripciones SQS y HTTP/S
- Los topics estándar no garantizan orden de entrega

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| Topic SNS estándar | `sns-{project_name}-{name}` | `sns-mi-proyecto-tf-notifications` |
| Topic SNS FIFO | `sns-{project_name}-{name}.fifo` | `sns-mi-proyecto-tf-events.fifo` |