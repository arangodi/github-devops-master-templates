# Módulo EC2

Crea instancias EC2 standalone o grupos de auto-scaling (ASG) con soporte para Linux y Windows. Soporta integración con ECS para correr containers con `launch_type: EC2`.

---

## Uso en config.yml

```yaml
catalog:
  compute:
    ec2_instances:
      - name: mi-servidor        # REQUERIDO
        instance_type: t3.medium
        os_type: linux
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre lógico de la instancia o grupo |

> `project_name`, `environment`, `vpc_id` y `subnet_ids` los inyecta el engine automáticamente.

---

### Instancia

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `os_type` | string | `linux` | `linux` \| `windows` | Sistema operativo |
| `instance_type` | string | `t3.micro` | Cualquier tipo EC2 | Tipo de instancia |
| `ami_id` | string | `null` | ID de AMI o `null` | AMI personalizada. `null` = última según `os_type` |
| `key_name` | string | `null` | Nombre del key pair o `null` | Key Pair para SSH/RDP. `null` = sin key pair |

---

### Red y acceso

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `enable_ssm` | bool | `false` | `true` \| `false` | Acceso via SSM Session Manager |
| `enable_rdp` | bool | `false` | `true` \| `false` | Acceso RDP. Solo Windows |
| `eni_id` | string | `null` | ID de ENI o `null` | ENI a asociar. `null` = IP dinámica |
| `additional_sg_ids` | list(string) | `[]` | Lista de IDs de SG | Security Groups adicionales |
| `ingress_rules` | list | `[]` | Ver estructura abajo | Reglas de ingreso al Security Group |

#### Estructura de `ingress_rules`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `from_port` | number | — | `0` - `65535` | Puerto inicial — **REQUERIDO** |
| `to_port` | number | — | `0` - `65535` | Puerto final — **REQUERIDO** |
| `protocol` | string | — | `tcp` \| `udp` \| `-1` | Protocolo — **REQUERIDO** |
| `cidr` | string | `10.0.0.0/8` | CIDR válido | Rango de IPs permitido |
| `description` | string | `""` | Cualquier string | Descripción de la regla |

```yaml
ingress_rules:
  - from_port: 8080
    to_port: 8080
    protocol: tcp
    cidr: "10.0.0.0/8"
    description: "API port"
```

---

### Almacenamiento

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `root_volume_size` | number | `20` | Número en GB | Tamaño del volumen root |
| `root_volume_type` | string | `gp3` | `gp2` \| `gp3` \| `io1` \| `io2` | Tipo del volumen root |
| `root_volume_encrypted` | bool | `true` | `true` \| `false` | Encriptar volumen root |
| `ebs_volumes` | list | `[]` | Ver estructura abajo | Volúmenes EBS adicionales |

#### Estructura de `ebs_volumes`

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `device_name` | string | — | `/dev/sd[f-z]` | Nombre del dispositivo — **REQUERIDO** |
| `size` | number | `20` | Número en GB | Tamaño del volumen |
| `type` | string | `gp3` | `gp2` \| `gp3` \| `io1` \| `io2` | Tipo del volumen |
| `encrypted` | bool | `true` | `true` \| `false` | Encriptar volumen |

```yaml
ebs_volumes:
  - device_name: /dev/sdf
    size: 100
    type: gp3
    encrypted: true
```

---

### User Data

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `user_data_script` | string | `null` | Nombre de archivo o `null` | Script predefinido en `scripts/userdata/`. Se ejecuta primero |
| `user_data_vars` | map(string) | `{}` | Mapa clave-valor | Variables a inyectar en el script via `templatefile()` |
| `user_data` | string | `null` | Script bash o powershell | Script inline adicional. Se concatena después de `user_data_script` |

> ℹ️ Si se usan `user_data_script` y `user_data` juntos, el script predefinido se ejecuta primero y el inline después.

#### Scripts predefinidos disponibles

| Script | Descripción | Variables requeridas |
|--------|-------------|---------------------|
| `ecs-agent.sh` | Instala agente ECS y registra la instancia en un cluster | `cluster_name` |

> Ver `scripts/userdata/README.md` para documentación completa de cada script.

---

### Integración con ECS

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `ecs_cluster_name` | string | `null` | Nombre corto del cluster o `null` | Registra la instancia en el cluster ECS. El engine resuelve el nombre completo automáticamente |

> ℹ️ Cuando se especifica `ecs_cluster_name`, el engine automáticamente:
> - Inyecta el script `ecs-agent.sh` como `user_data_script`
> - Pasa el nombre completo del cluster como variable al script
> - Agrega la política IAM `AmazonEC2ContainerServiceforEC2Role` al role de la instancia

---

### Auto Scaling Group (ASG)

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create_asg` | bool | `false` | `true` \| `false` | `true` = ASG, `false` = instancia standalone |
| `asg_min_size` | number | `1` | Número ≥ 0 | Mínimo de instancias |
| `asg_max_size` | number | `2` | Número ≥ `asg_min_size` | Máximo de instancias |
| `asg_desired_size` | number | `1` | Entre `min` y `max` | Número deseado de instancias |
| `on_demand_base_capacity` | number | `1` | Número ≥ 0 | Instancias On-Demand garantizadas |
| `on_demand_percentage` | number | `100` | `0` - `100` | % On-Demand sobre la capacidad base |
| `spot_instance_pools` | number | `2` | Número ≥ 1 | Pools de Spot instances |
| `additional_instance_types` | list(string) | `[]` | Lista de tipos EC2 | Tipos adicionales para mixed instances |

> ⚠️ `create_asg: true` es incompatible con `eni_id`

---

### Secrets Manager

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `secrets` | list(string) | `[]` | Lista de nombres de secrets | Secrets que la instancia puede leer |

```yaml
secrets:
  - db-credentials
  - api-keys
```

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Ejemplos

### Instancia Linux simple

```yaml
compute:
  ec2_instances:
    - name: backend-server
      os_type: linux
      instance_type: t3.medium
      enable_ssm: true
```

---

### Instancia con IP fija (ENI)

```yaml
networking:
  eni_interfaces:
    - name: backend-server
      private_ip: "10.26.74.70"

compute:
  ec2_instances:
    - name: backend-server
      os_type: linux
      instance_type: t3.medium
      eni_name: backend-server
      enable_ssm: true
```

---

### Instancia Windows con RDP

```yaml
compute:
  ec2_instances:
    - name: windows-server
      os_type: windows
      instance_type: t3.large
      enable_rdp: true
      enable_ssm: true
      root_volume_size: 50
      key_name: my-keypair
      ingress_rules:
        - from_port: 3389
          to_port: 3389
          protocol: tcp
          cidr: "10.0.0.0/8"
          description: "RDP access"
```

---

### Instancia con volúmenes adicionales

```yaml
compute:
  ec2_instances:
    - name: data-server
      os_type: linux
      instance_type: t3.large
      root_volume_size: 30
      ebs_volumes:
        - device_name: /dev/sdf
          size: 200
          type: gp3
          encrypted: true
```

---

### Instancia con user_data inline

```yaml
compute:
  ec2_instances:
    - name: app-server
      os_type: linux
      instance_type: t3.medium
      enable_ssm: true
      user_data: |
        #!/bin/bash
        yum update -y
        yum install -y docker
        systemctl start docker
        systemctl enable docker
```

---

### Instancia registrada en ECS

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
      ecs_cluster_name: cluster    # Solo el nombre corto — engine resuelve el resto

  ecs_services:
    - name: worker
      cluster: cluster
      task:
        launch_type: EC2           # Usa la instancia EC2 registrada
        use_placeholder: true
        cpu: 512
        memory: "1GB"
```

> ℹ️ El engine instala automáticamente el agente ECS en la instancia y la registra en el cluster. No necesitas configurar `user_data_script` manualmente.

---

### Instancia registrada en ECS con ASG

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

      # ASG para múltiples instancias en el cluster
      create_asg: true
      asg_min_size: 2
      asg_max_size: 10
      asg_desired_size: 3

      # Registrar todas las instancias del ASG en ECS
      ecs_cluster_name: cluster
```

---

### Instancia con script predefinido personalizado

```yaml
compute:
  ec2_instances:
    - name: monitoring-server
      os_type: linux
      instance_type: t3.medium
      enable_ssm: true

      # Script predefinido en scripts/userdata/
      user_data_script: monitoring-agent.sh
      user_data_vars:
        endpoint: "https://monitoring.example.com"
        api_key: "xxxx"
```

---

### ASG con Spot instances

```yaml
compute:
  ec2_instances:
    - name: workers
      os_type: linux
      instance_type: c5.xlarge

      create_asg: true
      asg_min_size: 2
      asg_max_size: 20
      asg_desired_size: 5

      on_demand_base_capacity: 2
      on_demand_percentage: 20
      spot_instance_pools: 4

      additional_instance_types:
        - c5.2xlarge
        - c5a.xlarge
        - c5a.2xlarge
```

---

### Completo con todas las opciones

```yaml
compute:
  ec2_instances:
    - name: full-example

      # Instancia
      os_type: linux
      instance_type: t3.large
      ami_id: null
      key_name: my-keypair

      # Red
      enable_ssm: true
      enable_rdp: false
      additional_sg_ids: []
      ingress_rules:
        - from_port: 8080
          to_port: 8080
          protocol: tcp
          cidr: "10.0.0.0/8"
          description: "App port"

      # Almacenamiento
      root_volume_size: 30
      root_volume_type: gp3
      root_volume_encrypted: true
      ebs_volumes:
        - device_name: /dev/sdf
          size: 100
          type: gp3
          encrypted: true

      # User data
      user_data_script: null       # Script predefinido en scripts/userdata/
      user_data_vars: {}           # Variables para el script
      user_data: null              # Script inline adicional

      # ECS
      ecs_cluster_name: null       # null = sin integración ECS

      # ASG
      create_asg: false
      asg_min_size: 1
      asg_max_size: 3
      asg_desired_size: 1
      on_demand_base_capacity: 1
      on_demand_percentage: 100
      spot_instance_pools: 2
      additional_instance_types: []

      # Secrets
      secrets:
        - db-credentials

      # Tags
      tags:
        team: backend
        component: app
```

---

## Restricciones

- `create_asg: true` es incompatible con `eni_id`
- `enable_rdp: true` solo aplica para `os_type: windows`
- `os_type: windows` usa AMI Windows Server 2022 Base por defecto
- `os_type: linux` usa AMI Amazon Linux 2023 por defecto
- `user_data_script` solo soporta scripts en `scripts/userdata/` — no rutas absolutas
- `ecs_cluster_name` requiere que el cluster exista antes de crear la instancia

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| Instancia EC2 | `ec2-{project_name}-{name}` | `ec2-mi-proyecto-tf-backend-server` |
| Security Group | `secg-{project_name}-{name}-ec2` | `secg-mi-proyecto-tf-backend-server-ec2` |
| ASG | `asg-{project_name}-{name}` | `asg-mi-proyecto-tf-workers` |
| IAM Role | `iam-{project_name}-{name}-ec2-role` | `iam-mi-proyecto-tf-backend-server-ec2-role` |