# Módulo ENI

Crea Elastic Network Interfaces con IP privada fija para instancias EC2 que requieren una dirección IP estable que no cambie entre reinicios o reemplazos de instancia.

---

## Uso en config.yml

```yaml
catalog:
  networking:
    eni_interfaces:
      - name: backend-server    # REQUERIDO
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre lógico del ENI |

> `project_name`, `environment`, `subnet_id` y `account` los inyecta el engine automáticamente.

---

### ENI

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `private_ip` | string | `null` | IP en CIDR de la subnet o `null` | IP privada fija. `null` = AWS asigna automáticamente pero se mantiene fija |
| `security_group_ids` | list(string) | `[]` | Lista de SG IDs | Security Groups asociados al ENI |
| `description` | string | `null` | Cualquier string | Descripción del ENI |
| `subnet_group` | string | `EC2` | `EC2` \| `ELB` \| `RDS` | Grupo de subnets donde se crea. El engine resuelve el ID automáticamente |
| `subnet_index` | number | `0` | `0` - `N` | Índice de la subnet dentro del grupo. `0` = primera subnet disponible |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## ⚠️ Comportamiento importante

El módulo crea el ENI con `prevent_destroy = true`. Esto significa:

- **`terraform destroy` no elimina el ENI** — debe eliminarse manualmente
- Protege contra pérdida accidental de la IP fija
- Si necesitas eliminar el ENI, primero debes hacer detach de la instancia

### Para eliminar un ENI manualmente

```bash
# 1. Desasociar de la instancia
aws ec2 detach-network-interface \
  --attachment-id eni-attach-xxxx \
  --region us-east-1

# 2. Eliminar el ENI
aws ec2 delete-network-interface \
  --network-interface-id eni-xxxx \
  --region us-east-1

# 3. Remover del state de Terraform
terraform state rm 'module.eni_interfaces["backend-server"].aws_network_interface.this[0]'

# 4. Ahora sí puedes hacer destroy
terraform destroy
```

---

## Ejemplos

### ENI con IP fija específica

```yaml
networking:
  eni_interfaces:
    - name: backend-server
      private_ip: "10.26.74.70"
```

---

### ENI con IP asignada por AWS (pero fija)

```yaml
networking:
  eni_interfaces:
    - name: worker-server
      # Sin private_ip → AWS asigna la IP pero queda fija al ENI
```

---

### ENI con Security Groups

```yaml
networking:
  eni_interfaces:
    - name: backend-server
      private_ip: "10.26.74.70"
      security_group_ids:
        - sg-abc123
        - sg-def456
```

---

### ENI en subnet específica

```yaml
networking:
  eni_interfaces:
    - name: backend-server
      private_ip: "10.26.74.70"
      subnet_group: EC2
      subnet_index: 1    # Segunda subnet del grupo EC2
```

---

### ENI asociado a EC2

```yaml
networking:
  eni_interfaces:
    - name: backend-server
      private_ip: "10.26.74.70"
      description: "ENI para backend-server con IP fija"

compute:
  ec2_instances:
    - name: backend-server
      os_type: linux
      instance_type: t3.medium
      eni_name: backend-server    # Referencia al ENI por nombre
      enable_ssm: true
```

> ℹ️ Cuando una instancia EC2 usa un ENI, la IP fija del ENI persiste incluso si la instancia es terminada y reemplazada.

---

### Múltiples ENIs para distintos servidores

```yaml
networking:
  eni_interfaces:
    - name: server-a
      private_ip: "10.26.74.70"

    - name: server-b
      private_ip: "10.26.74.71"

    - name: server-c
      private_ip: "10.26.74.72"

compute:
  ec2_instances:
    - name: server-a
      os_type: linux
      instance_type: t3.medium
      eni_name: server-a

    - name: server-b
      os_type: linux
      instance_type: t3.medium
      eni_name: server-b

    - name: server-c
      os_type: linux
      instance_type: t3.medium
      eni_name: server-c
```

---

### Completo con todas las opciones

```yaml
networking:
  eni_interfaces:
    - name: backend-server

      # IP
      private_ip: "10.26.74.70"

      # Red
      subnet_group: EC2
      subnet_index: 0
      security_group_ids:
        - sg-abc123

      # Metadata
      description: "ENI para backend-server con IP fija para integración legacy"

      # Tags
      tags:
        team: backend
        component: networking
```

---

## Cuándo usar ENI

| Escenario | ¿Usar ENI? |
|-----------|-----------|
| Servidor con IP que no puede cambiar (integración con firewall, whitelist) | ✓ Sí |
| Reemplazar instancia manteniendo la misma IP | ✓ Sí |
| Instancia normal sin requisitos de IP fija | ✗ No — usar IP dinámica |
| Auto Scaling Group | ✗ No — incompatible con ASG |
| ECS Fargate | ✗ No — Fargate gestiona sus propias ENIs |

---

## Restricciones

- `create_asg: true` en EC2 es incompatible con `eni_name` — el ASG gestiona sus propias interfaces
- El ENI tiene `prevent_destroy = true` — no se elimina con `terraform destroy`
- La `private_ip` debe estar dentro del CIDR de la subnet seleccionada
- Un ENI solo puede estar asociado a una instancia a la vez

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| ENI | `eni-{project_name}-{name}` | `eni-mi-proyecto-tf-backend-server` |