# Módulo S3

Crea buckets S3 con soporte para versionamiento, lifecycle policies, notificaciones, logging y replicación cross-region.

---

## Uso en config.yml

```yaml
catalog:
  storage:
    s3_buckets:
      - bucket_name: mi-proyecto-dev-uploads    # REQUERIDO — debe ser único globalmente
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `bucket_name` | string | Nombre del bucket. Debe ser único a nivel global en AWS |

> `project_name` y `environment` los inyecta el engine automáticamente para tags.

---

### Bucket

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `versioning` | bool | `false` | `true` \| `false` | Guarda todas las versiones de cada objeto |
| `encryption` | bool | `true` | `true` \| `false` | Encripción SSE-S3 de todos los objetos |
| `block_public_access` | bool | `true` | `true` \| `false` | Bloquea todo acceso público al bucket |
| `bucket_policy` | string | `null` | JSON string o `null` | Política de acceso al bucket. `null` = sin política adicional |

---

### Lifecycle Rules

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `lifecycle_rules` | list | `[]` | Ver estructura abajo | Reglas de ciclo de vida para mover o eliminar objetos automáticamente |

#### Estructura de `lifecycle_rules`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `id` | string | — | Cualquier string | Identificador único de la regla — **REQUERIDO** |
| `enabled` | bool | — | `true` \| `false` | Activar o desactivar la regla — **REQUERIDO** |
| `filter` | object | `null` | Ver estructura abajo | Filtro para aplicar la regla solo a ciertos objetos |
| `transitions` | list | `[]` | Ver estructura abajo | Mover objetos a otra storage class después de N días |
| `expiration` | object | `null` | Ver estructura abajo | Eliminar objetos después de N días |
| `noncurrent_version_transitions` | list | `[]` | Ver estructura abajo | Mover versiones antiguas a otra storage class |
| `noncurrent_version_expiration` | object | `null` | Ver estructura abajo | Eliminar versiones antiguas después de N días |
| `abort_incomplete_multipart_upload` | object | `null` | Ver estructura abajo | Cancelar uploads incompletos después de N días |

#### Estructura de `filter`

| Campo | Tipo | Valores aceptados | Descripción |
|-------|------|-------------------|-------------|
| `prefix` | string | Cualquier prefix | Aplica regla solo a objetos que empiezan con este prefix |
| `object_size_greater_than` | number | Bytes | Aplica solo a objetos mayores que N bytes |
| `object_size_less_than` | number | Bytes | Aplica solo a objetos menores que N bytes |
| `tags` | map(string) | Mapa clave-valor | Aplica solo a objetos con estos tags |

#### Storage classes disponibles para `transitions`

| Storage Class | Cuándo usar | Costo relativo |
|---------------|-------------|----------------|
| `STANDARD_IA` | Acceso infrecuente, disponibilidad inmediata | 40% menos |
| `INTELLIGENT_TIERING` | Acceso variable desconocido | Variable |
| `GLACIER_IR` | Archivado con recuperación en minutos | 68% menos |
| `GLACIER` | Archivado, recuperación en horas | 80% menos |
| `DEEP_ARCHIVE` | Archivado largo plazo, recuperación en 12h | 95% menos |

#### Estructura de `transitions`

```yaml
transitions:
  - days: 30
    storage_class: STANDARD_IA
  - days: 90
    storage_class: GLACIER
  - days: 180
    storage_class: DEEP_ARCHIVE
```

#### Estructura de `expiration`

```yaml
expiration:
  days: 365                            # Eliminar después de 365 días
  expired_object_delete_marker: false  # Eliminar delete markers huérfanos
```

#### Estructura de `noncurrent_version_expiration`

```yaml
noncurrent_version_expiration:
  noncurrent_days: 90           # Eliminar versiones antiguas después de 90 días
  newer_noncurrent_versions: 3  # Mantener las 3 últimas versiones antiguas
```

#### Estructura de `abort_incomplete_multipart_upload`

```yaml
abort_incomplete_multipart_upload:
  days_after_initiation: 7    # Cancelar uploads incompletos después de 7 días
```

---

### Logging

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `logging` | object | `null` | Ver estructura abajo | Guardar logs de acceso en otro bucket. `null` = sin logging |

#### Estructura de `logging`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `target_bucket` | string | — | Nombre de bucket | Bucket donde se guardan los logs — **REQUERIDO** |
| `target_prefix` | string | `logs/` | Cualquier prefix | Prefix de los objetos de log |

```yaml
logging:
  target_bucket: mi-proyecto-dev-logs
  target_prefix: "access-logs/"
```

---

### Notificaciones

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `notifications` | object | `null` | Ver estructura abajo | Notificar a Lambda, SQS o SNS cuando ocurren eventos. `null` = sin notificaciones |

#### Estructura de `notifications`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `lambda_arn` | string | `null` | ARN de Lambda o `null` | Lambda a invocar |
| `sqs_arn` | string | `null` | ARN de SQS o `null` | Cola SQS a notificar |
| `sns_arn` | string | `null` | ARN de SNS o `null` | Topic SNS a notificar |
| `events` | list(string) | `[s3:ObjectCreated:*]` | Ver eventos S3 | Eventos que disparan la notificación |
| `prefix` | string | `""` | Cualquier prefix | Solo notificar para objetos con este prefix |
| `suffix` | string | `""` | Cualquier sufijo | Solo notificar para objetos con este sufijo |

#### Eventos S3 disponibles

| Evento | Descripción |
|--------|-------------|
| `s3:ObjectCreated:*` | Cualquier creación de objeto |
| `s3:ObjectCreated:Put` | Solo PutObject |
| `s3:ObjectCreated:Post` | Solo POST form |
| `s3:ObjectCreated:Copy` | Solo CopyObject |
| `s3:ObjectRemoved:*` | Cualquier eliminación |
| `s3:ObjectRemoved:Delete` | Solo Delete |
| `s3:ObjectRestore:*` | Restauración desde Glacier |

---

### Replicación

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `replication` | object | `null` | Ver estructura abajo | Replicar objetos a otro bucket. `null` = sin replicación |

> ℹ️ Replicación requiere `versioning: true` en el bucket origen.

#### Estructura de `replication`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `role_arn` | string | — | ARN de IAM role | Role con permisos de replicación — **REQUERIDO** |
| `destination_bucket` | string | — | ARN de bucket S3 | Bucket destino — **REQUERIDO** |
| `destination_region` | string | — | Región AWS | Región del bucket destino — **REQUERIDO** |
| `replicate_delete` | bool | `false` | `true` \| `false` | Replicar también los deletes |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Ejemplos

### Bucket simple

```yaml
storage:
  s3_buckets:
    - bucket_name: mi-proyecto-dev-uploads
```

---

### Bucket con versionamiento

```yaml
storage:
  s3_buckets:
    - bucket_name: mi-proyecto-dev-documents
      versioning: true
```

---

### Bucket con lifecycle — mover a Glacier y expirar

```yaml
storage:
  s3_buckets:
    - bucket_name: mi-proyecto-dev-backups
      versioning: true
      lifecycle_rules:
        - id: mover-a-glacier
          enabled: true
          transitions:
            - days: 30
              storage_class: STANDARD_IA
            - days: 90
              storage_class: GLACIER
          expiration:
            days: 365
          noncurrent_version_expiration:
            noncurrent_days: 30
```

---

### Bucket con lifecycle por prefix

```yaml
storage:
  s3_buckets:
    - bucket_name: mi-proyecto-dev-data
      lifecycle_rules:
        # Logs → expirar rápido
        - id: limpiar-logs
          enabled: true
          filter:
            prefix: "logs/"
          expiration:
            days: 7

        # Reportes → archivar
        - id: archivar-reportes
          enabled: true
          filter:
            prefix: "reports/"
          transitions:
            - days: 60
              storage_class: GLACIER
          expiration:
            days: 730

        # Uploads temporales → cancelar multipart incompletos
        - id: limpiar-multipart
          enabled: true
          filter:
            prefix: "uploads/"
          abort_incomplete_multipart_upload:
            days_after_initiation: 3
```

---

### Bucket con notificaciones a Lambda

```yaml
storage:
  s3_buckets:
    - bucket_name: mi-proyecto-dev-uploads
      notifications:
        lambda_arn: arn:aws:lambda:us-east-1:123456789:function:process-upload
        events:
          - s3:ObjectCreated:*
        prefix: "uploads/"
        suffix: ".jpg"
```

---

### Bucket con notificaciones a SQS

```yaml
storage:
  s3_buckets:
    - bucket_name: mi-proyecto-dev-data
      notifications:
        sqs_arn: arn:aws:sqs:us-east-1:123456789:mi-cola.fifo
        events:
          - s3:ObjectCreated:*
          - s3:ObjectRemoved:*
```

---

### Bucket con logging

```yaml
storage:
  s3_buckets:
    # Bucket de logs
    - bucket_name: mi-proyecto-dev-access-logs
      block_public_access: true

    # Bucket principal con logging habilitado
    - bucket_name: mi-proyecto-dev-data
      logging:
        target_bucket: mi-proyecto-dev-access-logs
        target_prefix: "data-access/"
```

---

### Bucket con replicación cross-region

```yaml
storage:
  s3_buckets:
    - bucket_name: mi-proyecto-dev-primary
      versioning: true    # Requerido para replicación
      replication:
        role_arn: arn:aws:iam::123456789:role/s3-replication-role
        destination_bucket: arn:aws:s3:::mi-proyecto-dev-replica
        destination_region: us-west-2
        replicate_delete: false
```

---

### Bucket con política personalizada

```yaml
storage:
  s3_buckets:
    - bucket_name: mi-proyecto-dev-shared
      block_public_access: false    # Necesario para política pública
      bucket_policy: |
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": "*",
              "Action": "s3:GetObject",
              "Resource": "arn:aws:s3:::mi-proyecto-dev-shared/public/*"
            }
          ]
        }
```

---

### Completo con todas las opciones

```yaml
storage:
  s3_buckets:
    - bucket_name: mi-proyecto-dev-data

      # Bucket
      versioning: true
      encryption: true
      block_public_access: true

      # Lifecycle
      lifecycle_rules:
        - id: main-policy
          enabled: true
          filter:
            prefix: "data/"
          transitions:
            - days: 30
              storage_class: STANDARD_IA
            - days: 90
              storage_class: GLACIER
          expiration:
            days: 365
          noncurrent_version_expiration:
            noncurrent_days: 30
            newer_noncurrent_versions: 3
          abort_incomplete_multipart_upload:
            days_after_initiation: 7

      # Logging
      logging:
        target_bucket: mi-proyecto-dev-logs
        target_prefix: "data-access/"

      # Notificaciones
      notifications:
        sqs_arn: arn:aws:sqs:us-east-1:123456789:events.fifo
        events:
          - s3:ObjectCreated:*
        prefix: "uploads/"

      # Replicación
      replication:
        role_arn: arn:aws:iam::123456789:role/s3-replication
        destination_bucket: arn:aws:s3:::mi-proyecto-pdn-data
        destination_region: us-east-2
        replicate_delete: false

      # Tags
      tags:
        team: backend
        data-classification: confidential
```

---

## Restricciones

- `bucket_name` debe ser único globalmente en AWS — no solo en tu cuenta
- `replication` requiere `versioning: true`
- `block_public_access: false` es necesario para exponer objetos públicamente
- `bucket_policy: null` no crea política adicional — el bucket queda con acceso solo desde IAM
- `noncurrent_version_transitions` y `noncurrent_version_expiration` solo aplican cuando `versioning: true`
- Notificaciones solo pueden apuntar a Lambda, SQS o SNS — no a todos al mismo tiempo en la misma regla

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| Bucket S3 | `{bucket_name}` (exactamente como se declara) | `mi-proyecto-dev-uploads` |