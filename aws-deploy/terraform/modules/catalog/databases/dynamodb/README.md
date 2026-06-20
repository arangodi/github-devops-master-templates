# Módulo DynamoDB

Crea tablas DynamoDB con soporte para índices secundarios, auto-scaling, streams, TTL, encripción y point-in-time recovery.

---

## Uso en config.yml

```yaml
catalog:
  databases:
    dynamodb_tables:
      - name: users      # REQUERIDO
        hash_key: user_id  # REQUERIDO
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre de la tabla |
| `hash_key` | string | Nombre del partition key |

> `project_name`, `environment` y `account` los inyecta el engine automáticamente.

---

### Tabla

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create` | bool | `true` | `true` \| `false` | `true` = crea la tabla, `false` = referencia una existente |
| `existing_table_name` | string | `null` | Nombre de tabla o `null` | Nombre de tabla existente. Requerido si `create: false` |
| `billing_mode` | string | `null` | `PROVISIONED` \| `PAY_PER_REQUEST` \| `null` | `null` = automático según `enable_autoscaling` |
| `table_class` | string | `STANDARD` | `STANDARD` \| `STANDARD_INFREQUENT_ACCESS` | Clase de la tabla. `STANDARD_INFREQUENT_ACCESS` es 60% más barato para datos de acceso infrecuente |
| `deletion_protection_enabled` | bool | `false` | `true` \| `false` | Bloquea eliminación de la tabla en AWS |

> ℹ️ **Billing mode automático:** si `billing_mode: null` y `enable_autoscaling: false` → `PAY_PER_REQUEST`. Si `enable_autoscaling: true` → `PROVISIONED`.

---

### Claves

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `hash_key` | string | — | Cualquier string | Nombre del partition key — **REQUERIDO** |
| `hash_key_type` | string | `S` | `S` \| `N` \| `B` | Tipo del partition key. `S`=string, `N`=number, `B`=binary |
| `range_key` | string | `null` | Cualquier string o `null` | Nombre del sort key. `null` = sin sort key |
| `range_key_type` | string | `S` | `S` \| `N` \| `B` | Tipo del sort key |

---

### Capacidad — solo para `PROVISIONED`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `read_capacity` | number | `5` | Número ≥ 1 | Read capacity units iniciales |
| `write_capacity` | number | `5` | Número ≥ 1 | Write capacity units iniciales |

---

### Auto-scaling — solo para `PROVISIONED`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `enable_autoscaling` | bool | `false` | `true` \| `false` | Habilitar auto-scaling de capacidad |
| `autoscaling_read_max_capacity` | number | `100` | Número ≥ `read_capacity` | Capacidad máxima de read |
| `autoscaling_write_max_capacity` | number | `100` | Número ≥ `write_capacity` | Capacidad máxima de write |
| `autoscaling_read_target` | number | `70` | `1` - `100` | % de utilización de read para escalar |
| `autoscaling_write_target` | number | `70` | `1` - `100` | % de utilización de write para escalar |
| `autoscaling_scale_in_cooldown` | number | `60` | Segundos ≥ 0 | Cooldown antes de reducir capacidad |
| `autoscaling_scale_out_cooldown` | number | `60` | Segundos ≥ 0 | Cooldown antes de aumentar capacidad |

---

### Atributos adicionales

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `attributes` | list | `[]` | Ver estructura abajo | Atributos adicionales usados en GSI o LSI |

> ℹ️ Solo se declaran los atributos que se usan en índices. Los demás atributos de los items no se declaran aquí.

#### Estructura de `attributes`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `name` | string | — | Cualquier string | Nombre del atributo — **REQUERIDO** |
| `type` | string | — | `S` \| `N` \| `B` | Tipo del atributo — **REQUERIDO** |

```yaml
attributes:
  - name: email
    type: S
  - name: created_at
    type: N
```

---

### Global Secondary Indexes (GSI)

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `global_secondary_indexes` | list | `[]` | Ver estructura abajo | Índices globales secundarios. Máximo 20 |

#### Estructura de `global_secondary_indexes`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `name` | string | — | Cualquier string | Nombre del índice — **REQUERIDO** |
| `hash_key` | string | — | Nombre de atributo | Partition key del índice — **REQUERIDO** |
| `projection_type` | string | — | `ALL` \| `KEYS_ONLY` \| `INCLUDE` | Atributos proyectados — **REQUERIDO** |
| `range_key` | string | `null` | Nombre de atributo o `null` | Sort key del índice |
| `non_key_attributes` | list(string) | `null` | Lista de atributos | Atributos a proyectar. Solo si `projection_type: INCLUDE` |
| `read_capacity` | number | Hereda de tabla | Número ≥ 1 | Capacidad de read independiente. Solo `PROVISIONED` |
| `write_capacity` | number | Hereda de tabla | Número ≥ 1 | Capacidad de write independiente. Solo `PROVISIONED` |
| `enable_autoscaling` | bool | Hereda de tabla | `true` \| `false` | Auto-scaling independiente del índice |
| `autoscaling_read_max_capacity` | number | Hereda de tabla | Número ≥ 1 | Capacidad máxima de read del índice |
| `autoscaling_write_max_capacity` | number | Hereda de tabla | Número ≥ 1 | Capacidad máxima de write del índice |

```yaml
global_secondary_indexes:
  - name: email-index
    hash_key: email
    projection_type: ALL
```

---

### Local Secondary Indexes (LSI)

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `local_secondary_indexes` | list | `[]` | Ver estructura abajo | Índices locales secundarios. Máximo 5 |

> ⚠️ Los LSI solo se pueden definir al crear la tabla — no se pueden agregar después.

#### Estructura de `local_secondary_indexes`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `name` | string | — | Cualquier string | Nombre del índice — **REQUERIDO** |
| `range_key` | string | — | Nombre de atributo | Sort key alternativo — **REQUERIDO** |
| `projection_type` | string | — | `ALL` \| `KEYS_ONLY` \| `INCLUDE` | Atributos proyectados — **REQUERIDO** |
| `non_key_attributes` | list(string) | `null` | Lista de atributos | Atributos a proyectar. Solo si `projection_type: INCLUDE` |

```yaml
local_secondary_indexes:
  - name: status-index
    range_key: status
    projection_type: KEYS_ONLY
```

---

### Streams

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `stream_enabled` | bool | `false` | `true` \| `false` | Habilitar DynamoDB Streams |
| `stream_view_type` | string | `NEW_AND_OLD_IMAGES` | `NEW_IMAGE` \| `OLD_IMAGE` \| `NEW_AND_OLD_IMAGES` \| `KEYS_ONLY` | Tipo de datos en el stream |

| Tipo | Qué contiene | Cuándo usar |
|------|-------------|-------------|
| `NEW_IMAGE` | Item después del cambio | Procesamiento de eventos |
| `OLD_IMAGE` | Item antes del cambio | Auditoría de cambios |
| `NEW_AND_OLD_IMAGES` | Ambos | Auditoría completa |
| `KEYS_ONLY` | Solo las keys | Notificación de cambios (más barato) |

---

### TTL

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `ttl_enabled` | bool | `false` | `true` \| `false` | Auto-eliminar items expirados |
| `ttl_attribute_name` | string | `ttl` | Nombre de atributo | Atributo con el timestamp de expiración en epoch seconds |

> ℹ️ El atributo TTL debe ser de tipo `N` (number) con valor en epoch seconds. DynamoDB elimina los items dentro de las 48h siguientes a la expiración.

---

### Backup y recovery

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `point_in_time_recovery_enabled` | bool | `true` | `true` \| `false` | Restaurar tabla a cualquier punto en los últimos 35 días |

---

### Encripción

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `encryption_enabled` | bool | `true` | `true` \| `false` | Encriptar datos en reposo |
| `kms_key_arn` | string | `null` | ARN de KMS key o `null` | KMS key personalizada. `null` = AWS managed key |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Ejemplos

### Tabla simple

```yaml
databases:
  dynamodb_tables:
    - name: users
      hash_key: user_id
```

---

### Tabla con sort key

```yaml
databases:
  dynamodb_tables:
    - name: orders
      hash_key: customer_id
      hash_key_type: S
      range_key: order_date
      range_key_type: N
```

---

### Tabla con GSI

```yaml
databases:
  dynamodb_tables:
    - name: users
      hash_key: user_id

      attributes:
        - name: email
          type: S

      global_secondary_indexes:
        - name: email-index
          hash_key: email
          projection_type: ALL
```

---

### Tabla PROVISIONED con auto-scaling

```yaml
databases:
  dynamodb_tables:
    - name: products
      hash_key: product_id

      read_capacity: 10
      write_capacity: 5
      enable_autoscaling: true
      autoscaling_read_max_capacity: 200
      autoscaling_write_max_capacity: 100
      autoscaling_read_target: 70
      autoscaling_write_target: 70
```

---

### Tabla con stream para Lambda

```yaml
databases:
  dynamodb_tables:
    - name: orders
      hash_key: order_id

      stream_enabled: true
      stream_view_type: NEW_AND_OLD_IMAGES
```

---

### Tabla con TTL (sesiones)

```yaml
databases:
  dynamodb_tables:
    - name: sessions
      hash_key: session_id

      ttl_enabled: true
      ttl_attribute_name: expires_at
```

---

### Tabla de datos históricos (acceso infrecuente)

```yaml
databases:
  dynamodb_tables:
    - name: audit-log
      hash_key: log_id
      range_key: timestamp
      range_key_type: N

      table_class: STANDARD_INFREQUENT_ACCESS
      deletion_protection_enabled: true
```

---

### Tabla existente (referencia)

```yaml
databases:
  dynamodb_tables:
    - name: legacy
      create: false
      existing_table_name: my-old-table-name
      hash_key: id
```

---

### Integración con ECS Service

```yaml
databases:
  dynamodb_tables:
    - name: app-data
      hash_key: id

compute:
  ecs_services:
    - name: api
      cluster: cluster
      task:
        use_placeholder: true
        s3_bucket_names: []
      secrets: []
```

> ℹ️ El engine pasa automáticamente los ARNs de las tablas al ECS Service para los permisos IAM.

---

### Completo con todas las opciones

```yaml
databases:
  dynamodb_tables:
    - name: complete-example

      # Tabla
      create: true
      billing_mode: null
      table_class: STANDARD
      deletion_protection_enabled: true

      # Claves
      hash_key: pk
      hash_key_type: S
      range_key: sk
      range_key_type: S

      # Atributos para índices
      attributes:
        - name: gsi_pk
          type: S
        - name: lsi_sk
          type: N

      # Capacidad
      read_capacity: 5
      write_capacity: 5

      # Auto-scaling
      enable_autoscaling: true
      autoscaling_read_max_capacity: 100
      autoscaling_write_max_capacity: 100
      autoscaling_read_target: 70
      autoscaling_write_target: 70
      autoscaling_scale_in_cooldown: 60
      autoscaling_scale_out_cooldown: 60

      # GSI
      global_secondary_indexes:
        - name: gsi-1
          hash_key: gsi_pk
          projection_type: ALL
          enable_autoscaling: true
          autoscaling_read_max_capacity: 50
          autoscaling_write_max_capacity: 50

      # LSI
      local_secondary_indexes:
        - name: lsi-1
          range_key: lsi_sk
          projection_type: KEYS_ONLY

      # Streams
      stream_enabled: true
      stream_view_type: NEW_AND_OLD_IMAGES

      # TTL
      ttl_enabled: true
      ttl_attribute_name: ttl

      # Backup
      point_in_time_recovery_enabled: true

      # Encripción
      encryption_enabled: true
      kms_key_arn: null

      # Tags
      tags:
        team: backend
        data-criticality: high
```

---

## Restricciones

- `existing_table_name` requerido cuando `create: false`
- LSI solo se puede definir al crear la tabla — no se puede agregar después
- GSI se puede agregar después de crear la tabla
- `non_key_attributes` solo aplica cuando `projection_type: INCLUDE`
- `enable_autoscaling: true` fuerza `billing_mode: PROVISIONED`
- El atributo TTL debe ser tipo `N` con valor en epoch seconds
- Máximo 20 GSI y 5 LSI por tabla

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| Tabla DynamoDB | `dynamodb-{project_name}-{name}` | `dynamodb-mi-proyecto-tf-users` |