# Módulo ECS Cluster

Crea un cluster ECS con Fargate y Fargate Spot, roles IAM para ejecución y auto-scaling, y un Security Group interno para comunicación entre servicios.

---

## Uso en config.yml

```yaml
catalog:
  compute:
    ecs_clusters:
      - name: cluster    # REQUERIDO
        create: true
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre del cluster |

> `project_name`, `environment`, `vpc_id` y `account` los inyecta el engine automáticamente.

---

### Cluster

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create` | bool | `true` | `true` \| `false` | `true` = crea el cluster, `false` = referencia uno existente |
| `is_production` | bool | `false` | `true` \| `false` | Habilita Container Insights y prioriza FARGATE sobre FARGATE_SPOT |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Comportamiento según `is_production`

| Característica | `is_production: false` | `is_production: true` |
|----------------|----------------------|----------------------|
| **Container Insights** | Deshabilitado | ✅ Habilitado |
| **Capacity provider** | FARGATE_SPOT (primario) | FARGATE (primario) |
| **Costo** | Más económico | Más estable |
| **Disponibilidad** | Puede interrumpirse | Sin interrupciones |

---

## Outputs disponibles para ECS Services

El cluster expone automáticamente los siguientes valores que el engine usa al crear ECS Services:

| Output | Descripción |
|--------|-------------|
| `name` | Nombre del cluster para asociar servicios |
| `arn` | ARN del cluster |
| `internal_sg_id` | Security Group interno para comunicación entre servicios |
| `execution_role_arn` | IAM Role que ECS usa para hacer pull de ECR y escribir logs |
| `autoscaling_role_arn` | IAM Role para auto-scaling de servicios |

> ℹ️ No necesitas referenciar estos outputs manualmente — el engine los pasa automáticamente a cada ECS Service del mismo cluster.

---

## Ejemplos

### Cluster de desarrollo

```yaml
compute:
  ecs_clusters:
    - name: cluster
      create: true
```

---

### Cluster de producción

```yaml
compute:
  ecs_clusters:
    - name: cluster
      create: true
      is_production: true
```

---

### Completo con todas las opciones

```yaml
compute:
  ecs_clusters:
    - name: cluster

      create: true
      is_production: false   # true en pdn

      tags:
        team: platform
        component: ecs
```

---

## Relación con ECS Services

Un cluster debe existir antes de crear servicios. Los servicios lo referencian por nombre:

```yaml
compute:
  ecs_clusters:
    - name: cluster           # 1. Crear el cluster
      create: true

  ecs_services:
    - name: api
      cluster: cluster        # 2. El servicio referencia el cluster por name
```

---

## Restricciones

- Solo se puede tener un cluster por proyecto en la mayoría de los casos
- `create: false` requiere que el cluster ya exista en AWS con el naming esperado
- Los ECS Services dependen del cluster — debe aplicarse primero

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| ECS Cluster | `ecs-{project_name}-cluster` | `ecs-mi-proyecto-tf-cluster` |
| Security Group interno | `secg-{project_name}-container-internal` | `secg-mi-proyecto-tf-container-internal` |
| Execution Role | `iam-{project_name}-ecs-execution-role` | `iam-mi-proyecto-tf-ecs-execution-role` |
| Autoscaling Role | `iam-{project_name}-ecs-autoscaling-role` | `iam-mi-proyecto-tf-ecs-autoscaling-role` |