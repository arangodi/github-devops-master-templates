# Módulo ECS Service

Crea un servicio ECS en Fargate o EC2 con task definition, auto-scaling, service discovery, integración con ALB y acceso a Secrets Manager.

---

## Uso en config.yml

```yaml
catalog:
  compute:
    ecs_services:
      - name: api          # REQUERIDO
        cluster: cluster   # REQUERIDO
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre del servicio |
| `cluster` | string | Nombre del cluster ECS donde corre el servicio |

> `project_name`, `environment`, `vpc_id`, `subnet_ids`, `internal_sg_id`, `execution_role_arn` y `autoscaling_role_arn` los inyecta el engine automáticamente desde el cluster.

---

### Task — Launch Type

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `launch_type` | string | `FARGATE` | `FARGATE` \| `EC2` | Tipo de lanzamiento. `EC2` requiere instancias registradas en el cluster via `ecs_cluster_name` en el módulo EC2 |

> ℹ️ **Diferencias entre FARGATE y EC2:**
>
> | Aspecto | FARGATE | EC2 |
> |---------|---------|-----|
> | Infraestructura | AWS la gestiona | Tú la gestionas via módulo EC2 |
> | `network_mode` | `awsvpc` | `bridge` |
> | `cpu` / `memory` | Obligatorios | Opcionales |
> | `target_type` en ALB | `ip` | `instance` |
> | Costo | Por task | Por instancia |

---

### Task — Imagen

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `use_placeholder` | bool | `false` | `true` \| `false` | Usa imagen nginx hasta que CI haga el primer push |
| `placeholder_image` | string | `public.ecr.aws/nginx/nginx:alpine` | URI de imagen pública | Imagen dummy mientras no existe la real |
| `image_version` | string | `null` | Cualquier tag o `null` | Versión de la imagen. `null` = lee desde SSM |
| `image_version_ssm` | string | `null` | Nombre del parámetro SSM o `null` | SSM parameter con la versión. Se construye automáticamente si hay ECR asociado |
| `image_repo_uri` | string | Auto desde ECR | URI de imagen | URI del repositorio. Se resuelve automáticamente si hay ECR con el mismo `name` |

> ℹ️ En la mayoría de los casos no necesitas configurar la imagen manualmente. Si declaras un ECR con el mismo `name`, el engine lo resuelve automáticamente.

---

### Task — Recursos

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `cpu` | number | `256` | `256` \| `512` \| `1024` \| `2048` \| `4096` | CPU units de la task definition. Opcional en EC2 |
| `memory` | string | `0.5GB` | `0.5GB` \| `1GB` \| `2GB` \| `4GB` \| `8GB` \| `16GB` | Memoria de la task definition. Opcional en EC2 |
| `container_port` | number | `8080` | `1` - `65535` | Puerto donde escucha el contenedor |
| `desired_count` | number | `1` | Número ≥ 0 | Número de tareas deseadas |

---

### Task — IAM

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `task_role_create` | bool | `true` | `true` \| `false` | `true` = módulo crea el task role, `false` = usa uno existente |
| `task_role_arn` | string | `null` | ARN de IAM role o `null` | Task role existente. Solo si `task_role_create: false` |
| `task_managed_policies` | list(string) | `[]` | Lista de ARNs de policies | Managed policies adicionales al task role |
| `s3_bucket_names` | list(string) | `[]` | Lista de nombres de buckets | Buckets S3 accesibles. `[]` = acceso de solo lectura a todos |
| `s3_actions` | list(string) | `[s3:GetObject, s3:ListBucket]` | Lista de acciones S3 | Acciones permitidas cuando se usan `s3_bucket_names` |

---

### Task — Health Check

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `health_check_path` | string | `/` | Cualquier path | Path del health check HTTP |
| `enable_container_health_check` | bool | `false` | `true` \| `false` | Health check a nivel de contenedor (Docker). No aplica con placeholder |
| `health_check_grace_period` | number | `60` | Número en segundos | Segundos de gracia antes de iniciar health checks del servicio |

---

### Load Balancer

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `elb` | string | `null` | Nombre del ELB o `null` | Nombre del ELB a asociar. `null` = sin load balancer |
| `base_path` | string | `/` | Cualquier path | Path base para la regla del listener |
| `listener_priority` | number | `1` | `1` - `50000` | Prioridad de la regla en el listener. Debe ser único por listener |

> ⚠️ Si dos servicios usan el mismo listener, deben tener `listener_priority` diferente.

---

### Service Discovery

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `namespace` | string | `null` | Nombre del namespace o `null` | Namespace de Service Discovery. `null` = sin discovery |

> ℹ️ Con service discovery habilitado, el servicio es accesible en `{name}.{project_name}.net` desde otros servicios del mismo VPC.

---

### Auto-scaling

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `autoscaling.min` | number | `2` | Número ≥ 0 | Mínimo de tareas |
| `autoscaling.max` | number | `4` | Número ≥ `min` | Máximo de tareas |
| `autoscaling.target_cpu` | number | `80` | `1` - `100` | % de CPU para escalar |

---

### Secrets Manager

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `secrets` | list(string) | `[]` | Lista de nombres de secrets | Secrets inyectados como variables de entorno al contenedor |

> ℹ️ Los secrets se inyectan automáticamente como variables de entorno. El nombre del secret se convierte en el nombre de la variable en mayúsculas: `db-credentials` → `DB_CREDENTIALS`.

---

### Logs

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `log_retention_days` | number | `30` | `1` \| `7` \| `14` \| `30` \| `60` \| `90` \| `180` \| `365` | Días de retención en CloudWatch Logs |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Ejemplos

### Servicio simple Fargate sin ALB

```yaml
compute:
  ecs_clusters:
    - name: cluster
      create: true

  ecr_repositories:
    - name: worker
      create_ssm_parameter: true

  ecs_services:
    - name: worker
      cluster: cluster
      task:
        cpu: 256
        memory: "0.5GB"
        use_placeholder: true
```

---

### Servicio con ALB interno

```yaml
networking:
  elbs:
    - name: internal-alb
      load_balancer_type: application
      internal: true
      port: 443
      certificate_arn: arn:aws:acm:...

compute:
  ecs_services:
    - name: api
      cluster: cluster
      task:
        cpu: 512
        memory: "1GB"
        container_port: 8080
        use_placeholder: true
        health_check_path: /api/health
        health_check_grace_period: 60

      elb: internal-alb
      base_path: /api
      listener_priority: 10
```

---

### Servicio con launch_type EC2

```yaml
compute:
  ecs_clusters:
    - name: cluster
      create: true

  ec2_instances:
    - name: worker-host
      os_type: linux
      instance_type: t3.large
      enable_ssm: true
      ecs_cluster_name: cluster    # Registra la instancia en el cluster

  ecr_repositories:
    - name: worker
      create_ssm_parameter: true

  ecs_services:
    - name: worker
      cluster: cluster
      task:
        launch_type: EC2           # ← Usa la instancia EC2
        use_placeholder: true
        # cpu y memory son opcionales en EC2
```

> ℹ️ Con `launch_type: EC2` el servicio corre en las instancias EC2 registradas en el cluster. El módulo EC2 se encarga de instalar el agente ECS y registrar la instancia automáticamente cuando se especifica `ecs_cluster_name`.

---

### Servicio EC2 con ASG (múltiples instancias)

```yaml
compute:
  ecs_clusters:
    - name: cluster
      create: true

  ec2_instances:
    - name: ecs-workers
      os_type: linux
      instance_type: t3.large
      enable_ssm: true
      create_asg: true
      asg_min_size: 2
      asg_max_size: 10
      asg_desired_size: 3
      ecs_cluster_name: cluster

  ecs_services:
    - name: worker
      cluster: cluster
      task:
        launch_type: EC2
        use_placeholder: true
      autoscaling:
        min: 2
        max: 10
        target_cpu: 70
```

---

### Servicio con Service Discovery

```yaml
networking:
  namespaces:
    - name: ns-mi-proyecto
      create: true

compute:
  ecs_services:
    - name: backend
      cluster: cluster
      namespace: ns-mi-proyecto
      task:
        cpu: 256
        memory: "0.5GB"
        use_placeholder: true
```

> El servicio queda accesible en `backend.mi-proyecto-tf.net` desde otros servicios.

---

### Servicio con Secrets Manager

```yaml
security:
  secrets:
    - name: db-credentials
      secret_value:
        host: "db.example.com"
        username: "admin"
        password: "changeme"

compute:
  ecs_services:
    - name: api
      cluster: cluster
      task:
        cpu: 256
        memory: "0.5GB"
        use_placeholder: true
      secrets:
        - db-credentials    # Inyectado como DB_CREDENTIALS en el contenedor
```

---

### Servicio con acceso a S3 específico

```yaml
compute:
  ecs_services:
    - name: processor
      cluster: cluster
      task:
        cpu: 512
        memory: "1GB"
        use_placeholder: true
        s3_bucket_names:
          - mi-proyecto-dev-uploads
        s3_actions:
          - s3:GetObject
          - s3:PutObject
          - s3:ListBucket
```

---

### Servicio con auto-scaling personalizado

```yaml
compute:
  ecs_services:
    - name: api
      cluster: cluster
      task:
        cpu: 512
        memory: "1GB"
        desired_count: 2
        use_placeholder: true
      autoscaling:
        min: 2
        max: 10
        target_cpu: 70
```

---

### Completo con todas las opciones

```yaml
compute:
  ecs_services:
    - name: api

      # Cluster
      cluster: cluster

      # Task — imagen
      task:
        launch_type: FARGATE       # FARGATE | EC2
        use_placeholder: true
        placeholder_image: public.ecr.aws/nginx/nginx:alpine

        # Recursos (obligatorios en FARGATE, opcionales en EC2)
        cpu: 512
        memory: "1GB"
        container_port: 8080
        desired_count: 2

        # IAM
        task_role_create: true
        task_managed_policies: []
        s3_bucket_names: []
        s3_actions:
          - s3:GetObject
          - s3:ListBucket

        # Health check
        health_check_path: /health
        enable_container_health_check: false
        health_check_grace_period: 60

        # Logs
        log_retention_days: 30

      # Load Balancer
      elb: internal-alb
      base_path: /api
      listener_priority: 10

      # Service Discovery
      namespace: ns-mi-proyecto

      # Auto-scaling
      autoscaling:
        min: 2
        max: 10
        target_cpu: 70

      # Secrets
      secrets:
        - db-credentials
        - api-jwt-key

      # Tags
      tags:
        team: backend
        component: api
```

---

## Lógica de imagen

```
use_placeholder: true
      → Usa placeholder_image (nginx) siempre ✅

use_placeholder: false + SSM = "latest"
      → Usa placeholder_image hasta primer build ✅

use_placeholder: false + SSM = "20260528.1"
      → Usa imagen real del ECR ✅
```

> El engine resuelve la imagen automáticamente si existe un ECR con el mismo `name` que el servicio.

---

## Restricciones

- `cluster` debe existir antes de crear el servicio
- `launch_type: EC2` requiere instancias EC2 registradas en el cluster via `ecs_cluster_name` en el módulo EC2
- `listener_priority` debe ser único por listener
- `enable_container_health_check: true` no aplica cuando `use_placeholder: true`
- `task_role_arn` solo se usa cuando `task_role_create: false`
- `cpu` y `memory` son obligatorios en FARGATE y opcionales en EC2

### Combinaciones válidas CPU / Memoria en Fargate

| CPU | Memoria válida |
|-----|----------------|
| `256` | `0.5GB`, `1GB`, `2GB` |
| `512` | `1GB`, `2GB`, `3GB`, `4GB` |
| `1024` | `2GB` a `8GB` |
| `2048` | `4GB` a `16GB` |
| `4096` | `8GB` a `30GB` |

> En EC2 las combinaciones no tienen restricciones — dependen de la instancia disponible.

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| ECS Service | `ecs-{project_name}-{name}-service` | `ecs-mi-proyecto-tf-api-service` |
| Task Definition | `ecs-{project_name}-{name}-task` | `ecs-mi-proyecto-tf-api-task` |
| Task Role | `iam-{project_name}-{name}-task-role` | `iam-mi-proyecto-tf-api-task-role` |
| Security Group | `secg-{project_name}-{name}-container` | `secg-mi-proyecto-tf-api-container` |
| Log Group | `/ecs/task/{project_name}/{environment}/{name}` | `/ecs/task/mi-proyecto-tf/dev/api` |