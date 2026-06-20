# Módulo ECR

Crea repositorios de imágenes Docker en Amazon ECR con soporte para lifecycle policies, encripción y acceso cross-account.

---

## Uso en config.yml

```yaml
catalog:
  compute:
    ecr_repositories:
      - name: mi-servicio    # REQUERIDO
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre del repositorio |

> `project_name`, `environment` y `account` los inyecta el engine automáticamente.

---

### Repositorio

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create` | bool | `true` | `true` \| `false` | `true` = crea el repositorio, `false` = referencia uno existente |
| `existing_uri` | string | `null` | URI de ECR o `null` | URI del repositorio existente. Requerido si `create: false` |
| `image_tag_mutability` | string | `MUTABLE` | `MUTABLE` \| `IMMUTABLE` | Permite o bloquea sobreescribir tags existentes |
| `scan_on_push` | bool | `true` | `true` \| `false` | Escanear vulnerabilidades al hacer push |

---

### Encripción

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `encryption_type` | string | `KMS` | `KMS` \| `AES256` | Tipo de encripción del repositorio |
| `kms_key_arn` | string | `null` | ARN de KMS key o `null` | KMS key personalizada. `null` = key por defecto de AWS |

---

### Lifecycle Policy

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `lifecycle_policy` | object | `null` | Ver estructura abajo | Política de limpieza automática. `null` = sin política |

#### Estructura de `lifecycle_policy`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `keep_last_images` | number | `10` | Número ≥ 1 | Cantidad de imágenes tagged a conservar |
| `expire_untagged_after_days` | number | `7` | Número ≥ 1 | Días antes de eliminar imágenes sin tag |

```yaml
lifecycle_policy:
  keep_last_images: 10           # Opcional — default: 10
  expire_untagged_after_days: 7  # Opcional — default: 7
```

---

### Acceso cross-account

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `allow_account_ids` | list(string) | `[]` | Lista de AWS Account IDs | Cuentas que pueden hacer pull del repositorio |

```yaml
allow_account_ids:
  - "123456789012"
  - "987654321098"
```

---

### Integración con ECS

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create_ssm_parameter` | bool | `false` | `true` \| `false` | Crea SSM parameter para versionar la imagen. Necesario para ECS |
| `image_version` | string | `latest` | Cualquier string | Versión inicial del SSM parameter |

> ℹ️ Cuando `create_ssm_parameter: true` se crea el parámetro `{project_name}-{name}-image-version` en SSM.
> El pipeline CI lo actualiza en cada build. El engine de ECS lo lee para saber qué imagen desplegar.

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Ejemplos

### Repositorio simple

```yaml
compute:
  ecr_repositories:
    - name: api-backend
```

---

### Para ECS con SSM parameter

```yaml
compute:
  ecr_repositories:
    - name: api-backend
      create_ssm_parameter: true
```

> El engine de ECS usa automáticamente el SSM parameter para resolver la imagen.

---

### Con lifecycle policy

```yaml
compute:
  ecr_repositories:
    - name: api-backend
      create_ssm_parameter: true
      lifecycle_policy:
        keep_last_images: 20
        expire_untagged_after_days: 3
```

---

### Con tags inmutables (producción)

```yaml
compute:
  ecr_repositories:
    - name: api-backend
      image_tag_mutability: IMMUTABLE
      create_ssm_parameter: true
      lifecycle_policy:
        keep_last_images: 30
        expire_untagged_after_days: 7
```

---

### Repositorio existente (referencia)

```yaml
compute:
  ecr_repositories:
    - name: legacy-service
      create: false
      existing_uri: 123456789.dkr.ecr.us-east-1.amazonaws.com/mi-repo
```

---

### Con acceso cross-account

```yaml
compute:
  ecr_repositories:
    - name: shared-library
      allow_account_ids:
        - "123456789012"   # Cuenta de producción
        - "987654321098"   # Cuenta de staging
```

---

### Con KMS key personalizada

```yaml
compute:
  ecr_repositories:
    - name: api-backend
      encryption_type: KMS
      kms_key_arn: arn:aws:kms:us-east-1:123456789:key/abc-def-ghi
```

---

### Completo con todas las opciones

```yaml
compute:
  ecr_repositories:
    - name: api-backend

      # Repositorio
      create: true
      image_tag_mutability: MUTABLE
      scan_on_push: true

      # Encripción
      encryption_type: KMS
      kms_key_arn: null

      # Lifecycle
      lifecycle_policy:
        keep_last_images: 10
        expire_untagged_after_days: 7

      # Cross-account
      allow_account_ids: []

      # ECS
      create_ssm_parameter: true
      image_version: latest

      # Tags
      tags:
        team: backend
        component: api
```

---

## Flujo con ECS

```
ECR crea repositorio
      ↓
create_ssm_parameter: true
      ↓
SSM parameter creado: {project_name}-{name}-image-version = "latest"
      ↓
ECS Service arranca con placeholder (nginx) porque SSM = "latest"
      ↓
CI hace build → push ECR → actualiza SSM a "20260528.1"
      ↓
CD corre → ECS lee SSM "20260528.1" → despliega imagen real
```

---

## Restricciones

- `existing_uri` es requerido cuando `create: false`
- `kms_key_arn` solo aplica cuando `encryption_type: KMS`
- `image_tag_mutability: IMMUTABLE` impide sobreescribir tags existentes — recomendado para producción
- `create_ssm_parameter: true` es necesario para la integración automática con ECS

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| Repositorio ECR | `ecr-{project_name}-{name}` | `ecr-mi-proyecto-tf-api-backend` |
| SSM Parameter | `{project_name}-{name}-image-version` | `mi-proyecto-tf-api-backend-image-version` |