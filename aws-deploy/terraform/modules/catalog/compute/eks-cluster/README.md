# Módulo EKS Cluster

Crea un cluster Kubernetes en Amazon EKS con soporte para Managed Node Groups, Fargate Profiles, IRSA, add-ons y control de acceso.

---

## Uso en config.yml

```yaml
catalog:
  compute:
    eks_clusters:
      - name: cluster    # REQUERIDO
        create: true
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre del cluster |

> `project_name`, `environment`, `vpc_id`, `subnet_ids` y `account` los inyecta el engine automáticamente.

---

### Cluster

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create` | bool | `true` | `true` \| `false` | `true` = crea el cluster, `false` = referencia uno existente |
| `kubernetes_version` | string | `null` | Versión semántica o `null` | Versión de Kubernetes. `null` = última disponible en AWS |
| `enable_irsa` | bool | `false` | `true` \| `false` | Habilita IAM Roles for Service Accounts |
| `authentication_mode` | string | `API_AND_CONFIG_MAP` | `CONFIG_MAP` \| `API` \| `API_AND_CONFIG_MAP` | Modo de autenticación del cluster |
| `enable_load_balancer_controller` | bool | `false` | `true` \| `false` | Crea IAM Role para AWS Load Balancer Controller. Requiere `enable_irsa: true` |

---

### Node Groups

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `node_groups` | list | `[]` | Ver estructura abajo | Managed Node Groups del cluster |

#### Estructura de `node_groups`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `name` | string | — | Cualquier string | Nombre del node group — **REQUERIDO** |
| `instance_types` | list(string) | `[t3.medium]` | Lista de tipos EC2 | Tipos de instancia. Más de uno activa mixed instances |
| `min_size` | number | `1` | Número ≥ 0 | Mínimo de nodos |
| `max_size` | number | `3` | Número ≥ `min_size` | Máximo de nodos |
| `desired_size` | number | `2` | Entre `min` y `max` | Número deseado de nodos |
| `disk_size` | number | `20` | Número en GB | Tamaño del disco por nodo |
| `capacity_type` | string | `ON_DEMAND` | `ON_DEMAND` \| `SPOT` | Tipo de capacidad |
| `labels` | map(string) | `{}` | Mapa clave-valor | Labels de Kubernetes para los nodos |
| `taints` | list | `[]` | Ver estructura abajo | Taints de Kubernetes para los nodos |

#### Estructura de `taints`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `key` | string | — | Cualquier string | Clave del taint — **REQUERIDO** |
| `value` | string | — | Cualquier string | Valor del taint — **REQUERIDO** |
| `effect` | string | — | `NO_SCHEDULE` \| `PREFER_NO_SCHEDULE` \| `NO_EXECUTE` | Efecto del taint — **REQUERIDO** |

```yaml
node_groups:
  - name: general
    instance_types: ["t3.medium"]
    min_size: 1
    max_size: 5
    desired_size: 2
    disk_size: 20
    capacity_type: ON_DEMAND
    labels:
      role: general
    taints:
      - key: dedicated
        value: general
        effect: NO_SCHEDULE
```

---

### Fargate Profiles

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `fargate_profiles` | list | `[]` | Ver estructura abajo | Fargate Profiles del cluster |

#### Estructura de `fargate_profiles`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `name` | string | — | Cualquier string | Nombre del perfil — **REQUERIDO** |
| `namespace` | string | `default` | Namespace de Kubernetes | Namespace donde aplica el perfil |
| `labels` | map(string) | `{}` | Mapa clave-valor | Labels para seleccionar pods |

```yaml
fargate_profiles:
  - name: default
    namespace: default
    labels:
      compute-type: fargate
```

---

### Add-ons

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `addon_coredns_version` | string | `null` | Versión del add-on o `null` | Versión de CoreDNS. `null` = versión por defecto |
| `addon_kube_proxy_version` | string | `null` | Versión del add-on o `null` | Versión de kube-proxy. `null` = versión por defecto |
| `addon_vpc_cni_version` | string | `null` | Versión del add-on o `null` | Versión de vpc-cni. `null` = versión por defecto |

---

### Control de acceso

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `access_entries` | list | `[]` | Ver estructura abajo | Roles o usuarios con acceso al cluster |

#### Estructura de `access_entries`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `principal_arn` | string | — | ARN de IAM role o user | Principal con acceso — **REQUERIDO** |
| `type` | string | `STANDARD` | `STANDARD` \| `FARGATE_LINUX` \| `EC2_LINUX` | Tipo de access entry |
| `kubernetes_groups` | list(string) | `[]` | Lista de grupos | Grupos de Kubernetes asociados |
| `policy_associations` | list | `[]` | Ver estructura abajo | Políticas EKS asociadas |

#### Estructura de `policy_associations`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `policy_arn` | string | — | ARN de policy EKS | Policy a asociar — **REQUERIDO** |
| `access_scope` | string | `cluster` | `cluster` \| `namespace` | Alcance de la policy |
| `namespaces` | list(string) | `[]` | Lista de namespaces | Namespaces si `access_scope: namespace` |

```yaml
access_entries:
  - principal_arn: arn:aws:iam::123456789:role/developer-role
    type: STANDARD
    kubernetes_groups:
      - developers
    policy_associations:
      - policy_arn: arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy
        access_scope: namespace
        namespaces:
          - default
          - staging
```

---

### Secrets Manager

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `secrets` | list(string) | `[]` | Lista de nombres de secrets | Secrets accesibles desde el cluster |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Ejemplos

### Cluster simple con node group

```yaml
compute:
  eks_clusters:
    - name: cluster
      create: true
      node_groups:
        - name: general
          instance_types: ["t3.medium"]
          min_size: 1
          max_size: 3
          desired_size: 2
```

---

### Cluster con Fargate

```yaml
compute:
  eks_clusters:
    - name: cluster
      create: true
      fargate_profiles:
        - name: default
          namespace: default
        - name: kube-system
          namespace: kube-system
```

---

### Cluster con node groups On-Demand y Spot

```yaml
compute:
  eks_clusters:
    - name: cluster
      create: true
      node_groups:
        # Nodos críticos — On-Demand
        - name: core
          instance_types: ["t3.large"]
          min_size: 2
          max_size: 5
          desired_size: 2
          capacity_type: ON_DEMAND
          labels:
            role: core

        # Workers — Spot para ahorrar costos
        - name: workers
          instance_types: ["t3.large", "t3.xlarge", "t3a.large"]
          min_size: 0
          max_size: 20
          desired_size: 3
          capacity_type: SPOT
          labels:
            role: worker
```

---

### Cluster con IRSA y Load Balancer Controller

```yaml
compute:
  eks_clusters:
    - name: cluster
      create: true
      enable_irsa: true
      enable_load_balancer_controller: true
      node_groups:
        - name: general
          instance_types: ["t3.medium"]
          min_size: 1
          max_size: 5
          desired_size: 2
```

---

### Cluster con versión específica y add-ons

```yaml
compute:
  eks_clusters:
    - name: cluster
      create: true
      kubernetes_version: "1.29"
      addon_coredns_version: "v1.11.1-eksbuild.4"
      addon_kube_proxy_version: "v1.29.0-eksbuild.1"
      addon_vpc_cni_version: "v1.16.0-eksbuild.1"
      node_groups:
        - name: general
          instance_types: ["t3.medium"]
          min_size: 1
          max_size: 3
          desired_size: 2
```

---

### Cluster con control de acceso

```yaml
compute:
  eks_clusters:
    - name: cluster
      create: true
      authentication_mode: API_AND_CONFIG_MAP
      access_entries:
        - principal_arn: arn:aws:iam::123456789:role/developer-role
          kubernetes_groups:
            - developers
          policy_associations:
            - policy_arn: arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy
              access_scope: cluster
      node_groups:
        - name: general
          instance_types: ["t3.medium"]
          min_size: 1
          max_size: 3
          desired_size: 2
```

---

### Completo con todas las opciones

```yaml
compute:
  eks_clusters:
    - name: cluster

      # Cluster
      kubernetes_version: "1.29"
      enable_irsa: true
      authentication_mode: API_AND_CONFIG_MAP
      enable_load_balancer_controller: true

      # Node Groups
      node_groups:
        - name: general
          instance_types: ["t3.medium", "t3.large"]
          min_size: 1
          max_size: 5
          desired_size: 2
          disk_size: 30
          capacity_type: ON_DEMAND
          labels:
            role: general
          taints: []

      # Fargate
      fargate_profiles:
        - name: serverless
          namespace: serverless
          labels:
            compute-type: fargate

      # Add-ons
      addon_coredns_version: null
      addon_kube_proxy_version: null
      addon_vpc_cni_version: null

      # Acceso
      access_entries:
        - principal_arn: arn:aws:iam::123456789:role/admin-role
          type: STANDARD
          kubernetes_groups:
            - system:masters

      # Secrets
      secrets:
        - kubeconfig-credentials

      # Tags
      tags:
        team: platform
        component: eks
```

---

## Modos de autenticación

| Modo | Descripción | Cuándo usar |
|------|-------------|-------------|
| `CONFIG_MAP` | Solo via `aws-auth` ConfigMap | Clusters existentes legacy |
| `API` | Solo via EKS Access Entries API | Clusters nuevos |
| `API_AND_CONFIG_MAP` | Ambos métodos | Migración o compatibilidad |

---

## Restricciones

- `enable_load_balancer_controller: true` requiere `enable_irsa: true`
- `access_scope: namespace` requiere al menos un namespace en `namespaces`
- Node groups y Fargate profiles pueden coexistir en el mismo cluster
- `capacity_type: SPOT` requiere múltiples `instance_types` para evitar interrupciones

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| EKS Cluster | `eks-{project_name}-cluster` | `eks-mi-proyecto-tf-cluster` |
| Node Group | `eks-{project_name}-{name}-ng` | `eks-mi-proyecto-tf-general-ng` |
| Fargate Profile | `eks-{project_name}-{name}-fp` | `eks-mi-proyecto-tf-default-fp` |
| Cluster Role | `iam-{project_name}-eks-cluster-role` | `iam-mi-proyecto-tf-eks-cluster-role` |
| Node Role | `iam-{project_name}-eks-node-role` | `iam-mi-proyecto-tf-eks-node-role` |