# Módulo Secrets Manager

Crea y gestiona secrets en AWS Secrets Manager con soporte para rotación automática, roles IAM de acceso y resource policies.

---

## Uso en config.yml

```yaml
catalog:
  security:
    secrets:
      - name: db-credentials    # REQUERIDO
        secret_value:
          username: admin
          password: changeme
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre lógico del secret |

> `project_name`, `environment` y `account` los inyecta el engine automáticamente.

---

### Secret

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create` | bool | `true` | `true` \| `false` | `true` = crea el secret, `false` = referencia uno existente |
| `existing_secret_arn` | string | `null` | ARN de secret o `null` | ARN del secret existente. Requerido si `create: false` |
| `description` | string | `null` | Cualquier string | Descripción del secret |
| `secret_type` | string | `string` | `string` \| `binary` | Tipo de contenido del secret |
| `secret_value` | any | `null` | Objeto o string | Valor inicial. Los objetos se convierten a JSON automáticamente |
| `kms_key_id` | string | `null` | ARN o ID de KMS key o `null` | Encripción personalizada. `null` = AWS managed key |
| `recovery_window_days` | number | `0` | `0` \| `7` - `30` | Días antes de eliminar definitivamente. `0` = eliminación inmediata |

> ⚠️ El `secret_value` inicial es solo para bootstrap — después de creado, actualiza el valor desde la aplicación o manualmente. Terraform ignora cambios al valor después de la creación.

> ℹ️ **`recovery_window_days` por ambiente:** el engine configura automáticamente `0` en dev/qa/uat y `7` en pdn para evitar el error de "secret scheduled for deletion" durante pruebas.

---

### Rotación automática

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `enable_rotation` | bool | `false` | `true` \| `false` | Habilitar rotación automática del secret |
| `rotation_lambda_arn` | string | `null` | ARN de Lambda o `null` | Lambda que realiza la rotación. Requerido si `enable_rotation: true` |
| `rotation_days` | number | `30` | Número ≥ 1 | Cada cuántos días rotar el secret |
| `rotation_duration` | string | `2h` | Duración en formato `Nh` | Ventana de tiempo para completar la rotación |

---

### Roles IAM — creación automática

El módulo puede crear roles IAM dedicados para leer o escribir el secret:

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create_reader_role` | bool | `false` | `true` \| `false` | Crear rol IAM con permisos de lectura |
| `reader_role_name` | string | `null` | Cualquier string o `null` | Nombre del rol reader. `null` = genera `{project}-{name}-reader` |
| `reader_role_trusted_services` | list(string) | `[lambda.amazonaws.com]` | Lista de servicios AWS | Servicios que pueden asumir el reader role |
| `reader_role_trusted_arns` | list(string) | `[]` | Lista de ARNs | Roles/usuarios cross-account que pueden asumir el reader role |
| `create_writer_role` | bool | `false` | `true` \| `false` | Crear rol IAM con permisos de escritura |
| `writer_role_name` | string | `null` | Cualquier string o `null` | Nombre del rol writer. `null` = genera `{project}-{name}-writer` |
| `writer_role_trusted_services` | list(string) | `[lambda.amazonaws.com]` | Lista de servicios AWS | Servicios que pueden asumir el writer role |
| `writer_role_trusted_arns` | list(string) | `[]` | Lista de ARNs | Roles/usuarios cross-account que pueden asumir el writer role |

---

### Resource Policy — acceso desde roles existentes

Para otorgar acceso a roles IAM que ya existen sin crear nuevos:

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `reader_role_arns` | list(string) | `[]` | Lista de ARNs | Roles con permisos de lectura sobre el secret |
| `writer_role_arns` | list(string) | `[]` | Lista de ARNs | Roles con permisos de lectura y escritura |
| `admin_role_arns` | list(string) | `[]` | Lista de ARNs | Roles con acceso completo (`secretsmanager:*`) |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Permisos por tipo de rol

| Rol | Acciones permitidas |
|-----|---------------------|
| **reader** | `GetSecretValue`, `DescribeSecret`, `GetResourcePolicy` |
| **writer** | `GetSecretValue`, `DescribeSecret`, `PutSecretValue`, `UpdateSecret`, `GetResourcePolicy` |
| **admin** | `secretsmanager:*` |

---

## Ejemplos

### Secret de base de datos

```yaml
security:
  secrets:
    - name: db-credentials
      description: "Credenciales de la base de datos"
      secret_value:
        host: "db.example.com"
        port: "5432"
        dbname: "mydb"
        username: "admin"
        password: "changeme"
```

---

### Secret usado por ECS Service

```yaml
security:
  secrets:
    - name: db-credentials
      secret_value:
        username: admin
        password: changeme

compute:
  ecs_services:
    - name: api
      cluster: cluster
      task:
        use_placeholder: true
      secrets:
        - db-credentials    # Inyectado como DB_CREDENTIALS en el contenedor
```

---

### Secret con rotación automática

```yaml
security:
  secrets:
    - name: rds-master-password
      secret_value:
        password: changeme
      enable_rotation: true
      rotation_lambda_arn: arn:aws:lambda:us-east-1:123456789:function:rotate-secret
      rotation_days: 30
      rotation_duration: 2h
```

---

### Secret con roles de acceso creados automáticamente

```yaml
security:
  secrets:
    - name: api-keys
      secret_value:
        stripe_key: sk_test_xxxx
        sendgrid_key: SG.xxxx

      # Crear rol para que Lambda pueda leer
      create_reader_role: true
      reader_role_trusted_services:
        - lambda.amazonaws.com
        - ecs-tasks.amazonaws.com

      # Crear rol para que una Lambda de rotación pueda escribir
      create_writer_role: true
      writer_role_trusted_services:
        - lambda.amazonaws.com
```

---

### Secret con acceso cross-account

```yaml
security:
  secrets:
    - name: shared-credentials
      secret_value:
        token: "xxxx"

      # Otorgar acceso a un rol de otra cuenta AWS
      reader_role_arns:
        - arn:aws:iam::987654321098:role/external-consumer-role

      admin_role_arns:
        - arn:aws:iam::123456789012:role/platform-admin-role
```

---

### Secret existente (referencia)

```yaml
security:
  secrets:
    - name: legacy-credentials
      create: false
      existing_secret_arn: arn:aws:secretsmanager:us-east-1:123456789:secret:my-secret-abc123
```

---

### Secret con KMS personalizado

```yaml
security:
  secrets:
    - name: sensitive-data
      secret_value:
        api_key: "xxxx"
      kms_key_id: arn:aws:kms:us-east-1:123456789:key/abc-def-ghi
```

---

### Completo con todas las opciones

```yaml
security:
  secrets:
    - name: db-credentials

      # Secret
      create: true
      description: "Credenciales de base de datos producción"
      secret_type: string
      secret_value:
        host: "db.example.com"
        port: "5432"
        dbname: "mydb"
        username: "admin"
        password: "changeme"

      # Encripción
      kms_key_id: null

      # Eliminación
      recovery_window_days: 0    # 0 en dev, 7 en pdn (engine lo maneja)

      # Rotación
      enable_rotation: false
      rotation_lambda_arn: null
      rotation_days: 30
      rotation_duration: 2h

      # Roles automáticos
      create_reader_role: true
      reader_role_name: null
      reader_role_trusted_services:
        - ecs-tasks.amazonaws.com
      reader_role_trusted_arns: []

      create_writer_role: false
      writer_role_name: null
      writer_role_trusted_services:
        - lambda.amazonaws.com
      writer_role_trusted_arns: []

      # Resource policy
      reader_role_arns: []
      writer_role_arns: []
      admin_role_arns: []

      # Tags
      tags:
        team: backend
        data-classification: sensitive
```

---

## Integración con ECS Service

Los secrets se inyectan como variables de entorno en el contenedor. El nombre de la variable se genera así:

```
secret name: db-credentials  →  variable: DB_CREDENTIALS
secret name: api-jwt-key     →  variable: API_JWT_KEY
```

El valor completo del secret (JSON) queda disponible en la variable de entorno.

---

## Restricciones

- `existing_secret_arn` requerido cuando `create: false`
- `rotation_lambda_arn` requerido cuando `enable_rotation: true`
- `recovery_window_days` acepta solo `0` o valores entre `7` y `30`
- `secret_value` se ignora después de la creación — Terraform no sobreescribe cambios manuales
- `reader_role_arns` y `create_reader_role` son independientes — pueden usarse juntos o por separado
- `kms_key_id` puede ser el ARN completo, el ID o el alias (`alias/my-key`)

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| Secret | `{project_name}-{name}` | `mi-proyecto-tf-db-credentials` |
| Reader Role | `{project_name}-{name}-reader` | `mi-proyecto-tf-db-credentials-reader` |
| Writer Role | `{project_name}-{name}-writer` | `mi-proyecto-tf-db-credentials-writer` |