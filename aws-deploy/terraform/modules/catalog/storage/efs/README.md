# Módulo EFS

Crea un filesystem EFS (Elastic File System) con mount targets por AZ, access points y security group. Soporta integración con ECS, EKS y EC2.

---

## Uso en config.yml

```yaml
catalog:
  storage:
    efs_filesystems:
      - name: shared-files    # REQUERIDO
        access_points:
          - name: mi-servicio
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre lógico del filesystem |

> `project_name`, `environment`, `account`, `vpc_id` y `subnet_ids` los inyecta el engine automáticamente.

---

### Filesystem

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create` | bool | `true` | `true` \| `false` | `true` = crea el filesystem, `false` = referencia uno existente |
| `existing_filesystem_id` | string | `null` | ID de filesystem o `null` | ID del filesystem existente. Requerido si `create: false` |
| `performance_mode` | string | `generalPurpose` | `generalPurpose` \| `maxIO` | Modo de performance del filesystem |
| `throughput_mode` | string | `bursting` | `bursting` \| `provisioned` \| `elastic` | Modo de throughput |
| `provisioned_throughput_in_mibps` | number | `null` | Número en MiB/s | Throughput fijo. Solo si `throughput_mode: provisioned` |
| `transition_to_ia` | string | `null` | Ver tabla abajo | Mover archivos a Infrequent Access después de N días |

#### Valores de `transition_to_ia`

| Valor | Descripción |
|-------|-------------|
| `null` | Sin transición — archivos siempre en Standard |
| `AFTER_7_DAYS` | Mover a IA después de 7 días sin acceso |
| `AFTER_14_DAYS` | Mover a IA después de 14 días sin acceso |
| `AFTER_30_DAYS` | Mover a IA después de 30 días sin acceso |
| `AFTER_60_DAYS` | Mover a IA después de 60 días sin acceso |
| `AFTER_90_DAYS` | Mover a IA después de 90 días sin acceso |

> ℹ️ Infrequent Access (IA) es hasta un 92% más barato que Standard — ideal para archivos de licencias, configs o datos históricos que se acceden raramente.

---

### Performance

| Modo | Cuándo usar | Límite |
|------|-------------|--------|
| `generalPurpose` | La mayoría de casos — latencia baja | 35,000 ops/s |
| `maxIO` | Cargas masivamente paralelas (big data, HPC) | Sin límite, mayor latencia |
| `bursting` | Cargas variables — escala con el tamaño del filesystem | Proporcional al storage |
| `provisioned` | Necesitas throughput fijo independiente del tamaño | Hasta 3 GiB/s |
| `elastic` | Cargas impredecibles — AWS escala automáticamente | Hasta 3 GiB/s |

---

### Encripción

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `encryption_enabled` | bool | `true` | `true` \| `false` | Encripción at rest de todos los datos |
| `kms_key_arn` | string | `null` | ARN de KMS key o `null` | KMS key personalizada. `null` = AWS managed key |

---

### Backup

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `enable_backup` | bool | `true` | `true` \| `false` | Habilitar AWS Backup automático |

---

### Access Points

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `access_points` | list | `[]` | Ver estructura abajo | Un access point por servicio que monta el filesystem |

> ℹ️ Los access points crean un directorio aislado dentro del filesystem para cada servicio. Cada servicio solo ve su propio directorio — no puede acceder al de otros servicios.

#### Estructura de `access_points`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `name` | string | — | Cualquier string | Nombre del access point — **REQUERIDO** |
| `path` | string | `/` | Cualquier path | Directorio raíz del access point dentro del filesystem |
| `uid` | number | `1000` | Número ≥ 0 | UID del usuario propietario del directorio |
| `gid` | number | `1000` | Número ≥ 0 | GID del grupo propietario del directorio |
| `permissions` | string | `755` | Permisos Linux | Permisos del directorio en formato octal |

> ℹ️ **`uid` y `gid`** deben coincidir con el usuario que corre el proceso dentro del container. Si el container corre como `root` (uid=0), usar `uid: 0, gid: 0`.

```yaml
access_points:
  - name: validation-engine
    path: /validation
    uid: 1000
    gid: 1000
    permissions: "755"
```

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Ejemplos

### Filesystem simple

```yaml
storage:
  efs_filesystems:
    - name: shared-files
```

---

### Filesystem con access points para ECS

```yaml
storage:
  efs_filesystems:
    - name: shared-files
      access_points:
        - name: validation-engine
          path: /validation
        - name: report-engine
          path: /reports
        - name: audit
          path: /audit
```

---

### Filesystem para licencia (acceso infrecuente)

```yaml
storage:
  efs_filesystems:
    - name: lbn-license
      throughput_mode: bursting
      transition_to_ia: AFTER_30_DAYS    # Mover a IA — acceso infrecuente
      enable_backup: true
      access_points:
        - name: lbn
          path: /license
          uid: 1000
          gid: 1000
          permissions: "755"
```

---

### Filesystem existente (referencia)

```yaml
storage:
  efs_filesystems:
    - name: legacy-files
      create: false
      existing_filesystem_id: fs-abc123def
```

---

### Filesystem con alto throughput

```yaml
storage:
  efs_filesystems:
    - name: high-throughput
      throughput_mode: provisioned
      provisioned_throughput_in_mibps: 100    # 100 MiB/s fijo
      performance_mode: generalPurpose
```

---

### Integración con ECS Service

```yaml
storage:
  efs_filesystems:
    - name: shared-files
      access_points:
        - name: validation-engine
          path: /validation

compute:
  ecs_services:
    - name: validation-engine
      cluster: cluster
      task:
        use_placeholder: true

      # Montar EFS en el container
      efs:
        - name: shared              # Nombre del volumen en la task definition
          filesystem: shared-files  # Referencia al EFS por nombre
          access_point: validation-engine
          mount_path: /mnt/shared   # Ruta dentro del container
          read_only: false
```

---

### Completo con todas las opciones

```yaml
storage:
  efs_filesystems:
    - name: shared-files

      # Filesystem
      create: true
      performance_mode: generalPurpose
      throughput_mode: bursting
      provisioned_throughput_in_mibps: null

      # Lifecycle
      transition_to_ia: AFTER_30_DAYS

      # Backup
      enable_backup: true

      # Encripción
      encryption_enabled: true
      kms_key_arn: null

      # Access Points
      access_points:
        - name: service-a
          path: /service-a
          uid: 1000
          gid: 1000
          permissions: "755"

        - name: service-b
          path: /service-b
          uid: 1001
          gid: 1001
          permissions: "750"

      # Tags
      tags:
        team: platform
        component: storage
```

---

## Integración por tipo de recurso

### ECS Service

```yaml
ecs:
  - name: mi-volumen
    filesystem: shared-files       # Nombre del EFS en storage
    access_point: mi-servicio      # Nombre del access point
    mount_path: /mnt/shared        # Ruta en el container
    read_only: false
```

### EC2

El engine expone el comando de montaje via outputs. Agregar en `user_data`:

```bash
mount -t nfs4 fs-xxxx.efs.us-east-1.amazonaws.com:/ /mnt/shared
```

### EKS

El engine expone `filesystem_id` y `access_point_ids` para el CSI driver:

```yaml
# StorageClass en Kubernetes
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: fs-xxxx
  directoryPerms: "755"
```

---

## Restricciones

- `existing_filesystem_id` requerido cuando `create: false`
- `provisioned_throughput_in_mibps` solo aplica cuando `throughput_mode: provisioned`
- `performance_mode: maxIO` no es compatible con `throughput_mode: elastic`
- Los access points crean el directorio automáticamente si no existe
- El security group permite NFS (port 2049) solo desde `10.0.0.0/8`
- Se crea un mount target por cada subnet — una por AZ para alta disponibilidad

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| EFS Filesystem | `efs-{project_name}-{name}` | `efs-mi-proyecto-tf-shared-files` |
| Security Group | `secg-{project_name}-{name}-efs` | `secg-mi-proyecto-tf-shared-files-efs` |
| Access Point | `efs-ap-{project_name}-{access_point_name}` | `efs-ap-mi-proyecto-tf-validation-engine` |