# Módulo SQS

Crea colas SQS estándar o FIFO con soporte para dead letter queues, long polling y configuración de retención de mensajes.

---

## Uso en config.yml

```yaml
catalog:
  messaging:
    sqs_queues:
      - name: mi-cola    # REQUERIDO
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre lógico de la cola |

> `project_name`, `environment` y `account` los inyecta el engine automáticamente.

---

### Cola

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `fifo` | bool | `false` | `true` \| `false` | Crea una cola FIFO. Garantiza orden y entrega única |
| `content_based_deduplication` | bool | `false` | `true` \| `false` | Deduplicación automática por contenido. Solo para colas FIFO |
| `visibility_timeout` | number | `30` | `0` - `43200` segundos | Tiempo que un mensaje es invisible después de ser recibido |
| `message_retention_seconds` | number | `345600` | `60` - `1209600` segundos | Tiempo que SQS retiene mensajes no procesados. Default = 4 días |
| `delay_seconds` | number | `0` | `0` - `900` segundos | Retraso antes de que un mensaje sea visible en la cola |
| `maximum_message_size` | number | `262144` | `1024` - `262144` bytes | Tamaño máximo del mensaje. Default = 256 KB |
| `receive_message_wait_time_seconds` | number | `0` | `0` - `20` segundos | Tiempo de espera para long polling. `0` = short polling |

---

### Dead Letter Queue (DLQ)

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `dead_letter_queue` | object | `null` | Ver estructura abajo | Redirige mensajes fallidos a otra cola. `null` = sin DLQ |

#### Estructura de `dead_letter_queue`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `target_arn` | string | — | ARN de cola SQS | Cola destino para mensajes fallidos — **REQUERIDO** |
| `max_receive_count` | number | — | Número ≥ 1 | Intentos antes de enviar a DLQ — **REQUERIDO** |

> ℹ️ Cuando usas el engine del IDP, puedes referenciar la DLQ por nombre en lugar del ARN completo.

```yaml
dead_letter_queue:
  target_name: mi-cola-dlq    # Referencia por nombre (engine lo resuelve)
  max_receive_count: 3
```

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Referencia de tiempos

| Campo | Default | Mínimo | Máximo | Equivalencia del default |
|-------|---------|--------|--------|--------------------------|
| `visibility_timeout` | `30` | `0` | `43200` | 30 segundos |
| `message_retention_seconds` | `345600` | `60` | `1209600` | 4 días |
| `delay_seconds` | `0` | `0` | `900` | Sin retraso |
| `receive_message_wait_time_seconds` | `0` | `0` | `20` | Short polling |

---

## Ejemplos

### Cola estándar simple

```yaml
messaging:
  sqs_queues:
    - name: notifications
```

---

### Cola FIFO

```yaml
messaging:
  sqs_queues:
    - name: orders
      fifo: true
      content_based_deduplication: true
```

---

### Cola con DLQ

```yaml
messaging:
  sqs_queues:
    # DLQ — se crea primero
    - name: orders-dlq
      fifo: true

    # Cola principal — referencia la DLQ
    - name: orders
      fifo: true
      visibility_timeout: 45
      dead_letter_queue:
        target_name: orders-dlq
        max_receive_count: 3
```

---

### Cola con long polling

```yaml
messaging:
  sqs_queues:
    - name: processor
      receive_message_wait_time_seconds: 20    # Máximo long polling
      visibility_timeout: 60
```

> ℹ️ Long polling (`receive_message_wait_time_seconds > 0`) reduce costos al disminuir la cantidad de llamadas vacías a la API.

---

### Cola para procesamiento pesado

```yaml
messaging:
  sqs_queues:
    - name: etl-processor
      fifo: true
      visibility_timeout: 300       # 5 minutos para procesar
      message_retention_seconds: 86400  # 1 día
      receive_message_wait_time_seconds: 20
      dead_letter_queue:
        target_name: etl-processor-dlq
        max_receive_count: 2
```

---

### Patrón completo DLQ + Cola principal + SNS

```yaml
messaging:
  sqs_queues:
    # DLQs
    - name: etl-dlq
      fifo: true

    - name: audit-dlq
      fifo: true

    # Colas principales
    - name: etl
      fifo: true
      visibility_timeout: 45
      dead_letter_queue:
        target_name: etl-dlq
        max_receive_count: 3

    - name: audit
      fifo: true
      visibility_timeout: 45
      dead_letter_queue:
        target_name: audit-dlq
        max_receive_count: 3

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
```

---

### Completo con todas las opciones

```yaml
messaging:
  sqs_queues:
    - name: full-example

      # Cola
      fifo: true
      content_based_deduplication: true

      # Tiempos
      visibility_timeout: 60
      message_retention_seconds: 345600
      delay_seconds: 0
      maximum_message_size: 262144
      receive_message_wait_time_seconds: 20

      # DLQ
      dead_letter_queue:
        target_name: full-example-dlq
        max_receive_count: 3

      # Tags
      tags:
        team: backend
        component: messaging
```

---

## Diferencias FIFO vs Estándar

| Característica | Estándar | FIFO |
|----------------|----------|------|
| **Orden** | No garantizado | ✅ Garantizado |
| **Entrega** | Al menos una vez | ✅ Exactamente una vez |
| **Throughput** | Ilimitado | 300 msg/s (3000 con batching) |
| **Deduplicación** | No | ✅ Sí |
| **Compatibilidad SNS** | SNS estándar | Solo SNS FIFO |
| **Naming** | `nombre` | `nombre.fifo` |

---

## Restricciones

- `content_based_deduplication: true` solo aplica para colas FIFO
- `dead_letter_queue.target_name` debe ser una cola del mismo tipo (FIFO → FIFO, estándar → estándar)
- `visibility_timeout` debe ser mayor o igual al tiempo de procesamiento del consumer
- Colas FIFO solo pueden suscribirse a topics SNS FIFO

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| Cola SQS estándar | `sqs-{project_name}-{name}` | `sqs-mi-proyecto-tf-notifications` |
| Cola SQS FIFO | `sqs-{project_name}-{name}.fifo` | `sqs-mi-proyecto-tf-orders.fifo` |