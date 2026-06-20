# Módulo ELB

Crea Application Load Balancers (ALB) o Network Load Balancers (NLB) internos o públicos con listener, security group y protección contra borrado.

---

## Uso en config.yml

```yaml
catalog:
  networking:
    elbs:
      - name: internal-alb    # REQUERIDO
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre que indica el propósito del balanceador |

> `project_name`, `environment`, `vpc_id`, `subnet_ids` y `account` los inyecta el engine automáticamente.

---

### Load Balancer

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create` | bool | `true` | `true` \| `false` | `true` = crea el ELB, `false` = referencia uno existente |
| `load_balancer_type` | string | `application` | `application` \| `network` | Tipo de balanceador. `application` = ALB, `network` = NLB |
| `internal` | bool | `true` | `true` \| `false` | `true` = acceso solo desde la VPC, `false` = internet-facing |
| `deletion_protection` | bool | `true` | `true` \| `false` | Bloquea eliminación accidental del balanceador |

---

### Listener

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `port` | number | `443` | `1` - `65535` | Puerto del listener |
| `certificate_arn` | string | `null` | ARN de ACM o `null` | Certificado para HTTPS/TLS. `null` = protocolo HTTP o TCP |
| `ssl_policy` | string | `ELBSecurityPolicy-TLS13-1-2-Ext2-2021-06` | Ver políticas AWS | Política SSL/TLS del listener. Solo si `certificate_arn` está definido |
| `idle_timeout` | number | `60` | `1` - `4000` segundos | Tiempo de inactividad antes de cerrar conexión. Solo ALB |
| `default_target_group_arn` | string | `null` | ARN de target group o `null` | Target group por defecto del listener. Solo NLB |

> ℹ️ **Protocolo automático:**
> - ALB con `certificate_arn` → HTTPS
> - ALB sin `certificate_arn` → HTTP
> - NLB con `certificate_arn` → TLS
> - NLB sin `certificate_arn` → TCP

---

### Security Group — solo ALB

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `ingress_cidr` | string | `10.0.0.0/8` | CIDR válido | Rango de IPs permitido en el SG del balanceador |

> ℹ️ El NLB no usa Security Groups — este campo solo aplica para ALB.

---

### Subnets

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `subnet_group` | string | `ELB` | `ELB` \| `EC2` | Grupo de subnets donde se despliega. El engine resuelve los IDs automáticamente |

---

### Referencia a ELB existente

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `existing_arn` | string | `null` | ARN de ELB o `null` | ARN del balanceador existente. Solo si `create: false` |
| `existing_listener_arn` | string | `null` | ARN de listener o `null` | ARN del listener existente. Solo si `create: false` |
| `existing_sg_id` | string | `null` | ID de SG o `null` | ID del Security Group existente. Solo si `create: false` |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Diferencias ALB vs NLB

| Característica | ALB (`application`) | NLB (`network`) |
|----------------|--------------------|--------------------|
| **Protocolo** | HTTP / HTTPS | TCP / TLS |
| **Security Group** | ✅ Sí | ❌ No |
| **Listener rules** | ✅ Soporta path-based routing | ❌ Solo forward |
| **Idle timeout** | ✅ Configurable | ❌ No aplica |
| **Uso típico** | Servicios HTTP/HTTPS, ECS | VPC Link para API Gateway |
| **Target Group** | Creado por ECS Service | Requiere `default_target_group_arn` |

---

## Ejemplos

### ALB interno HTTP

```yaml
networking:
  elbs:
    - name: internal-alb
      load_balancer_type: application
      internal: true
      port: 80
```

---

### ALB interno HTTPS

```yaml
networking:
  elbs:
    - name: internal-alb
      load_balancer_type: application
      internal: true
      port: 443
      certificate_arn: arn:aws:acm:us-east-1:123456789:certificate/abc123
```

---

### NLB interno para API Gateway

```yaml
networking:
  elbs:
    - name: internal-nlb
      load_balancer_type: network
      internal: true
      port: 80
```

---

### NLB interno TLS

```yaml
networking:
  elbs:
    - name: internal-nlb
      load_balancer_type: network
      internal: true
      port: 443
      certificate_arn: arn:aws:acm:us-east-1:123456789:certificate/abc123
      ssl_policy: ELBSecurityPolicy-TLS13-1-2-2021-06
```

---

### ELB existente (referencia)

```yaml
networking:
  elbs:
    - name: existing-alb
      create: false
      existing_arn: arn:aws:elasticloadbalancing:us-east-1:123456789:loadbalancer/app/my-alb/abc
      existing_listener_arn: arn:aws:elasticloadbalancing:us-east-1:123456789:listener/app/my-alb/abc/def
      existing_sg_id: sg-abc123
```

---

### ALB + NLB juntos (patrón API Gateway + ECS)

```yaml
networking:
  elbs:
    # ALB para ECS Services con path-based routing
    - name: internal-alb
      load_balancer_type: application
      internal: true
      port: 443
      certificate_arn: arn:aws:acm:...

    # NLB para API Gateway VPC Link
    - name: internal-nlb
      load_balancer_type: network
      internal: true
      port: 80

  api_gateways:
    - name: public
      enable_vpc_link: true
      nlb_name: internal-nlb    # API Gateway apunta al NLB

compute:
  ecs_services:
    - name: api
      elb: internal-alb         # ECS Service apunta al ALB
      base_path: /api
      listener_priority: 10
```

---

### Completo con todas las opciones

```yaml
networking:
  elbs:
    - name: internal-alb

      # Load Balancer
      load_balancer_type: application
      internal: true
      deletion_protection: true

      # Listener
      port: 443
      certificate_arn: arn:aws:acm:us-east-1:123456789:certificate/abc123
      ssl_policy: ELBSecurityPolicy-TLS13-1-2-Ext2-2021-06
      idle_timeout: 60

      # Security Group
      ingress_cidr: "10.0.0.0/8"

      # Subnets
      subnet_group: ELB

      # Tags
      tags:
        team: platform
        component: networking
```

---

## Outputs disponibles para otros módulos

El engine expone automáticamente estos outputs para que ECS Services y API Gateway los consuman:

| Output | Descripción |
|--------|-------------|
| `arn` | ARN del balanceador |
| `dns_name` | DNS name para configurar Route53 |
| `listener_arn` | ARN del listener para crear reglas en ECS Services |
| `security_group_id` | ID del SG para permitir tráfico desde el balanceador al contenedor |
| `zone_id` | Zone ID para alias records en Route53 |

---

## Restricciones

- `certificate_arn` requerido cuando `port: 443`
- `idle_timeout` solo aplica para ALB — ignorado en NLB
- `ingress_cidr` solo aplica para ALB — NLB no tiene Security Group
- `default_target_group_arn` solo aplica para NLB
- `existing_arn` requerido cuando `create: false`
- Nombre final del ELB máximo 32 caracteres — usar nombres cortos en `name`
- NLB no soporta path-based routing — usar ALB si necesitas enrutar por path

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| ALB | `elb-{project_name}-{name}` | `elb-mi-proyecto-tf-internal-alb` |
| NLB | `nlb-{project_name}-{name}` | `nlb-mi-proyecto-tf-internal-nlb` |
| Security Group ALB | `secg-{project_name}-lb-{name}` | `secg-mi-proyecto-tf-lb-internal-alb` |