# Módulo Service Discovery (Namespace)

Crea un namespace privado de DNS en AWS Cloud Map para que los servicios ECS se descubran entre sí por nombre dentro de la VPC, sin necesidad de hardcodear IPs o endpoints.

---

## Uso en config.yml

```yaml
catalog:
  networking:
    namespaces:
      - name: ns-mi-proyecto    # REQUERIDO
```

---

## Parámetros

### Obligatorios

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `name` | string | Nombre lógico del namespace |

> `project_name`, `environment`, `vpc_id` y `account` los inyecta el engine automáticamente.

---

### Namespace

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `create` | bool | `true` | `true` \| `false` | `true` = crea el namespace, `false` = referencia uno existente |

---

### Otros

| Campo | Tipo | Default | Valores aceptados | Descripción |
|-------|------|---------|-------------------|-------------|
| `tags` | map(string) | `{}` | Mapa clave-valor | Tags adicionales |

---

## Cómo funciona

El namespace crea una zona DNS privada dentro de la VPC. Cuando un ECS Service se registra en el namespace, queda accesible por nombre desde cualquier otro servicio en la misma VPC:

```
Namespace: {project_name}.net

ECS Service "api"     → api.{project_name}.net
ECS Service "worker"  → worker.{project_name}.net
ECS Service "backend" → backend.{project_name}.net
```

El DNS se actualiza automáticamente cuando las tasks de ECS escalan o se reemplazan — siempre apunta a las IPs activas.

---

## Ejemplos

### Namespace simple

```yaml
networking:
  namespaces:
    - name: ns-mi-proyecto
      create: true
```

> El namespace queda disponible en `{project_name}.net` dentro de la VPC.

---

### Namespace con ECS Services

```yaml
networking:
  namespaces:
    - name: ns-mi-proyecto
      create: true

compute:
  ecs_services:
    - name: api
      cluster: cluster
      namespace: ns-mi-proyecto    # Registra el servicio en el namespace
      task:
        cpu: 256
        memory: "0.5GB"
        use_placeholder: true

    - name: worker
      cluster: cluster
      namespace: ns-mi-proyecto
      task:
        cpu: 256
        memory: "0.5GB"
        use_placeholder: true
```

Después del deploy, los servicios se pueden llamar entre sí:

```python
# Desde el contenedor "api" llamar al "worker"
import requests
response = requests.get("http://worker.mi-proyecto-tf.net:8080/process")
```

---

### Namespace existente (referencia)

```yaml
networking:
  namespaces:
    - name: ns-mi-proyecto
      create: false
      # El engine obtiene el ID del namespace existente automáticamente por nombre
```

---

### Completo con todas las opciones

```yaml
networking:
  namespaces:
    - name: ns-mi-proyecto

      create: true

      tags:
        team: platform
        component: networking
```

---

## Comunicación entre servicios

Con service discovery, los servicios se comunican directamente sin pasar por el ALB:

```
Sin service discovery:
  api → ALB → worker   (necesita pasar por el load balancer)

Con service discovery:
  api → worker.mi-proyecto-tf.net   (DNS directo dentro de la VPC)
```

### Registros DNS creados por servicio

Cada ECS Service registra dos tipos de registros:

| Tipo | Valor | Descripción |
|------|-------|-------------|
| `A` | IP de la task | Resuelve directamente a la IP del contenedor |
| `SRV` | IP + puerto | Resuelve a IP y puerto del contenedor |

---

## Restricciones

- El namespace es privado — solo accesible desde dentro de la VPC
- Un proyecto solo necesita un namespace — todos los servicios ECS lo comparten
- `create: false` requiere que el namespace ya exista con el nombre `{project_name}.net`
- El namespace no se puede renombrar después de creado

---

## Naming

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| Namespace DNS | `{project_name}.net` | `mi-proyecto-tf.net` |
| Registro de servicio | `{service_name}.{project_name}.net` | `api.mi-proyecto-tf.net` |