# DevOps Master Templates

Este repositorio contiene un conjunto centralizado de **plantillas** y **configuraciones reutilizables** para automatizar el ciclo completo de CI/CD en **Azure DevOps** e **infraestructura en AWS.**

Incluye pipelines estandarizados para **análisis de código** (SonarQube, Checkmarx, Semgrep, GitLeaks), **compilación y testing en múltiples lenguajes** (Java, Python, Go, Node.js, C#), **despliegue en AWS** (ECS) y módulos **Terraform** y **CloudFormation** para infraestructura como código. Las plantillas están organizadas por categoría y componente, facilitando su reutilización en proyectos con diferentes stacks tecnológicos.

---

##  Índice

- [Estructura del Repositorio](#estructura-del-repositorio)
- [Convenciones](#convenciones-usadas)
- [Pipelines CI/CD](#pipelines-cicd)
  - [Parámetros Globales](#parámetros-globales)
  - [Configuración por Lenguaje](#configuración-por-lenguaje)
    - [C# (.NET)](#c-net)
    - [Go](#go)
    - [Java](#java)
    - [Node.js](#nodejs)
    - [Python](#python)
  - [Pasos comunes para Pipeline CI](#pasos-comunes-en-el-pipeline-ci) 
- [Módulos Terraform](#módulos-terraform)
  - [Compute](#compute)
  - [Databases](#databases)
  - [Messaging](#messaging)
  - [Networking](#networking)
  - [Security](#security)
  - [Storage](#storage)
- [Troubleshooting](#troubleshooting)
- [Issues Conocidos](#known-issues--improvement-opportunities)
- [Contribuciones](#contribute)

---

## Estructura del Repositorio

```
devops-master-templates/
│
├── README.md                              # Este archivo
├── ci-pipeline.yml                        # Pipeline orquestador de CI
│
├── ci/                                    # Pipelines de Integración Continua
│   ├── build/                             # Templates para compilación
│   ├── run_tests/                         # Templates para testing
│   ├── checkmarx/                         # Análisis SAST con Checkmarx
│   ├── custom_breaker/                    # Evaluador de calidad
│   ├── gitleaks/                          # Detección de secretos
│   ├── semgrep/                           # Análisis de código estático
│   └── sonar/                             # Análisis con SonarQube
│
├── cd/                                    # Pipelines de Despliegue Continuo
│   └── cd-pipeline-ecs-service.yml        # Despliegue en ECS_SERVICE
│
├── aws-deploy/                            # Configuración de AWS
│   ├── cloudformation/                    # Templates CloudFormation
│   └── terraform/                         # Módulos y configuración Terraform
│       ├── engine/                        # Módulos principales
│       ├── modules/                       # Catálogo de módulos reutilizables
│       ├── pipelines/                     # Pipelines de validación
│       └── scripts/                       # Scripts auxiliares
│
├── service-pipelines/                     # Pipelines específicos de servicios
│   └── svc/                               # Templates y políticas IAM
│
├── pipelines-demo/                        # Ejemplos de pipelines
└── agent/                                 # Configuración del agente
    └── clean.yml                          # Pipeline de limpieza
```

---

## Convenciones Usadas

| Tipo | Convención | Ejemplo |
|------|------------|---------|
| parameters | snake_case | `work_path`, `language` |
| variables | camelCase | `nodeVersion`, `projectName` |
| env vars | UPPER_SNAKE_CASE | `AWS_REGION`, `SONARQUBE_HOST` |
| system vars | PascalCase con `.` | `Build.SourceBranchName`, `System.DefaultWorkingDirectory` |

---

## Pipelines CI/CD

### Parámetros Globales

| Parámetro | Tipo | Descripción | Requerido | Valores | Default |
|-----------|------|-------------|-----------|---------|---------|
| `language` | string | Lenguaje de programación | ✓ | `cs`, `go`, `java`, `node`, `python` | ✗ |
| `work_path` | string | Ruta del directorio de trabajo | ✓ | ✗ | ✗ |
| `containerized` | string | Tipo de containerización | ✗ | `true`, `false` | `false` |
| `cs_use_nuget_config` | boolean | Usa configuración NuGet (C# solo) | ✗ | `true`, `false` | `false` |


## Configuración por Lenguaje

### C# (.NET)

Análisis de proyectos .NET usando el scanner de dotnet.

**Requisitos:**
- Archivo `.sln` o `.slnx` en el directorio raíz
- Versión de .NET especificada

**Variables necesarias:**
- `netVersion` - Versión de .NET (ej: 6.0, 7.0, 8.0)
- `slnFile` - Nombre del archivo solution con extensión
- `nugetFile` - Nombre del archivo de configuración de NuGet (ej: nuget.config), **requerido si el parámetro `cs_use_nuget_config` es `true`**

**Ejemplos:**
```yaml
trigger:
  branches:
    include:
      - 'development'
      - 'release'
      - 'master'
  paths:
    exclude:
      - README.md
      - ci-azure-pipeline.yml

pool: 'BTG Colombia - Azure DevOps'

resources:
  repositories:
  - repository: devops-master-templates
    type: git
    name: devops-master-templates
    ref: validate
  
variables:
  - name: projectName
    value: project-name
  - name: netVersion
    value: 9.0
  - name: slnFile
    value: Project.SolutionFile
  - name: nugetFile
    value: nuget.config.template

stages:
  - template: ci-pipeline.yml@devops-master-templates
    parameters:
      language: cs
      work_path: $(System.DefaultWorkingDirectory)/$(project_dir)
```

```yaml
trigger:
  branches:
    include:
      - 'development'
      - 'release'
      - 'master'
  paths:
    exclude:
      - README.md
      - ci-azure-pipeline.yml
 
pool: 'BTG Colombia - Azure DevOps'
 
resources:
  repositories:
  - repository: devops-master-templates
    type: git
    name: devops-master-templates
    ref: master

variables:
  - name: serviceName
    value: maestros-unicos-api
  - name: imageVersion
    value: $(Build.BuildNumber)

  - name: netVersion
    value: 10.0
  - name: slnFile
    value: MaestrosUnicos.API.sln
 
stages:
  - template: ci-pipeline.yml@devops-master-templates
    parameters:
      language: cs
      work_path: $(System.DefaultWorkingDirectory)
      containerized: true
```

---

### Go

Análisis de proyectos Go con cobertura de código.

**Requisitos:**
- `go.mod` en el directorio raíz
- Tests con sufijo `*_test.go`

**Variables necesarias:**
- `goVersion` - Versión de Go

**Ejemplo:**
```yaml
trigger:
  branches:
    include:
      - 'development'
      - 'release'
      - 'master'
  paths:
    exclude:
      - README.md
      - ci-azure-pipeline.yml

pool: 'BTG Colombia - Azure DevOps'

resources:
  repositories:
  - repository: devops-master-templates
    type: git
    name: devops-master-templates
    ref: validate
  
variables:
  - name: goVersion
    value: 1.25

stages:
  - template: ci-pipeline.yml@devops-master-templates
    parameters:
      language: go
      work_path: $(System.DefaultWorkingDirectory)
```

---

### Java

Análisis básico de proyectos Java usando el scanner CLI.

**Requisitos:**
- Proyecto Maven o Gradle a nivel raíz (detectar automáticamente).

**Ejemplo:**
```yaml
trigger:
  branches:
    include:
      - development
      - qc
      - release
      - master
  paths:
    exclude:
      - ci-azure-pipeline.yml

pool:
  name: "BTG Colombia - Azure DevOps"
  demands:
    - Agent.Name -equals Agent-10-27-157-29

resources:
  repositories:
    - repository: devops-master-templates
      type: git
      name: devops-master-templates
      ref: temp/onboarding_validate

variables:
  - name: stage
    ${{ if eq(variables['Build.SourceBranchName'], 'development') }}:
      value: dev
    ${{ elseif eq(variables['Build.SourceBranchName'], 'release') }}:
      value: uat
    ${{ elseif eq(variables['Build.SourceBranchName'], 'master') }}:
      value: prod
    ${{ else }}:
      value: dev

  - name: awsCredentials
    value: SVC-SERVICE-IDP-DIGITAL-EXPERIENCES-${{ upper(variables.stage) }}

  - name: region
    value: us-east-1

  - name: project
    value: onboarding-invitation

  - name: ecrName
    value: ecr-onboarding-tf-invitation

  - name: serviceName
    value: invitation

  - name: version
    value: $(Build.BuildNumber)

  - name: dockerfilePath
    value: Dockerfile

  - name: buildContext
    value: .

stages:
  - template: ci-pipeline.yml@devops-master-templates
    parameters:
      language: java
      work_path: $(System.DefaultWorkingDirectory)
      containerized: eks
      java_multimodule_coverage: true
```

---

### Node.js

Análisis de proyectos Node.js y JavaScript/TypeScript.

**Requisitos:**
- `package.json` en el directorio raíz
- En los scripts de `package.json`, debe existir un comando para tests que genere un reporte de cobertura en formato LCOV (`coverage/lcov.info`), ejemplo para vite: 
```json
  "scripts": {
    "test": "vitest run --coverage --coverage.reporter=lcov"
  }
```

**Variables necesarias:**
- `nodeVersion` - Versión de Node.js

**Ejemplo:**
```yaml
trigger:
  branches:
    include:
      - 'development'
      - 'release'
      - 'master'
  paths:
    exclude:
      - README.md
      - ci-azure-pipeline.yml

pool: "BTG Colombia - Azure DevOps"

resources:
  repositories:
  - repository: devops-master-templates
    type: git
    name: devops-master-templates
    ref: validate

variables:
  - name: nodeVersion
    value: '22'

stages:
  - template: ci-pipeline.yml@devops-master-templates
    parameters:
      language: node
      work_path: $(System.DefaultWorkingDirectory)
```

---

### Python

Análisis de proyectos Python con cobertura.

**Requisitos:**
- Carpeta de `tests/` al mismo nivel que el código fuente (ej: `src/` y `tests/`).
- Archivo de requisitos `requirements.txt` dentro de `tests/` con las dependencias necesarias para ejecutar los tests.

**Variables necesarias:**
- `pythonVersion` - Versión de Python a usar. Valores permitidos: `3.9`, `3.10`, `3.11`, `3.12`.

**Ejemplo:**
```yaml
trigger:
  branches:
    include:
    - 'development'
    - 'release'
    - 'master'
  paths:
    include:
    - '*'
    exclude:
    - README.md
    - ci-azure-pipeline.yml

pool: 'BTG Colombia - Azure DevOps'

resources:
  repositories:
  - repository: devops-master-templates
    type: git
    name: devops-master-templates
    ref: validate
  
variables:
  - name: pythonVersion
    value: '3.9'

stages:
  - template: ci-pipeline.yml@devops-master-templates
    parameters:
      language: python
      work_path: $(System.DefaultWorkingDirectory)
```

---

## Pasos Comunes en el Pipeline CI 

### Pasos Comunes en Todos los Lenguajes

Independientemente del lenguaje, el pipeline ejecuta estos pasos después del análisis específico:

1. **SonarQubeAnalyze** - Ejecuta el análisis
2. **SonarQubePublish** - Publica los resultados (timeout: 300s)
3. **Quality Gate Check** - Verifica que la compuerta de calidad sea APROBADA

```bash
# La compuerta obtiene el projectKey de:
# 1. sonar-project.properties (si existe)
# 2. Variable de pipeline projectName
# 3. Nombre del repositorio (repo_name)
```

### Configuración de Variables de Pipeline

Es necesario configurar variables en Azure DevOps según el lenguaje:

### Común a todos:
- `projectName` - Nombre del proyecto en SonarQube

### Para C#:
- `net_version` - Versión de .NET (ej: 6, 7, 8)
- `slnFile` - Nombre del archivo .sln sin extensión
- `project_dir` - Directorio del proyecto (alternativa a slnFile)

### Para Go y Python:
- No requieren variables adicionales

### Para Node.js:
- Asegurar que exista `coverage/lcov.info` después de tests

---

## Módulos Terraform

Los módulos Terraform están organizados en el directorio `aws-deploy/terraform/modules/catalog/` y pueden ser reutilizados en múltiples configuraciones a traves de archivos de configuración. A continuación se describen los módulos disponibles por categoría:

###  Compute

Módulos para gestionar recursos de computación en AWS.

| Módulo | Descripción | Ubicación | Uso |
|--------|-------------|-----------|------|
| **EC2** | Instancias de máquinas virtuales | `modules/catalog/compute/ec2/` | [README del módulo EC2](./aws-deploy/terraform/modules/catalog/compute/ec2/README.md).
| **ECR** | Registro de contenedores | `modules/catalog/compute/ecr/` | [README del módulo ECR](./aws-deploy/terraform/modules/catalog/compute/ecr/README.md).
| **ECS Cluster** | Cluster de contenedores ECS | `modules/catalog/compute/ecs-cluster/` | [README del módulo ECS Cluster](./aws-deploy/terraform/modules/catalog/compute/ecs-cluster/README.md).
| **ECS Service** | Servicios dentro de ECS | `modules/catalog/compute/ecs-service/` | [README del módulo ECS Service](./aws-deploy/terraform/modules/catalog/compute/ecs-service/README.md).
| **EKS Cluster** | Cluster de Kubernetes en AWS | `modules/catalog/compute/eks-cluster/` | [README del módulo EKS Cluster](./aws-deploy/terraform/modules/catalog/compute/eks-cluster/README.md).
| **Glue** | Servicio de ETL de AWS Glue | `modules/catalog/compute/glue/` |


---

###  Databases

Módulos para gestionar bases de datos en AWS.

| Módulo | Descripción | Ubicación | Uso |
|--------|-------------|-----------|-----|
| **DynamoDB** | Base de datos NoSQL | `modules/catalog/databases/dynamodb/` | [README del módulo DynamoDB](./aws-deploy/terraform/modules/catalog/databases/dynamodb/README.md).
| **RDS** | Bases de datos relacionales | `modules/catalog/databases/rds/` |


---

###  Messaging

Módulos para servicios de mensajería y notificaciones en AWS.

| Módulo | Descripción | Ubicación | Uso |
|--------|-------------|-----------|-----|
| **SNS** | Servicio de notificaciones | `modules/catalog/messaging/sns/` | [README del módulo SNS](./aws-deploy/terraform/modules/catalog/messaging/sns/README.md).
| **SQS** | Colas de mensajes | `modules/catalog/messaging/sqs/` | [README del módulo SQS](./aws-deploy/terraform/modules/catalog/messaging/sqs/README.md).


---

###  Networking

Módulos para gestionar redes, balanceadores y APIs en AWS.

| Módulo | Descripción | Ubicación |Uso |
|--------|-------------|-----------|-----|
| **API Gateway** | Puerta de enlace REST/HTTP | `modules/catalog/networking/api-gateway/` | [README del módulo API Gateway](./aws-deploy/terraform/modules/catalog/networking/api-gateway/README.md).
| **ELB** | Balanceador de carga elástico | `modules/catalog/networking/elb/` | [README del módulo ELB](./aws-deploy/terraform/modules/catalog/networking/elb/README.md).
| **ENI** | Interfaces de red elásticas | `modules/catalog/networking/eni/` | [README del módulo ENI](./aws-deploy/terraform/modules/catalog/networking/eni/README.md).
| **Service Discovery** | Descubrimiento de servicios | `modules/catalog/networking/service-discovery/` | [README del módulo Service Discovery](./aws-deploy/terraform/modules/catalog/networking/service-discovey/README.md).
| **WebSocket API** | API WebSocket | `modules/catalog/networking/websocket-api/` |

---

###  Security

Módulos para seguridad, certificados e identidades en AWS.

| Módulo | Descripción | Ubicación | Uso |
|--------|-------------|-----------|-----|
| **IAM** | Gestión de identidades y accesos | `modules/catalog/security/iam/` |
| **Secrets Manager** | Gestión de secretos | `modules/catalog/security/secrets-manager/` | [README del módulo Secret Manager](./aws-deploy/terraform/modules/catalog/security/secrets-manager/README.md).

---

###  Storage

Módulos para almacenamiento en AWS.

| Módulo | Descripción | Ubicación | Uso |
|--------|-------------|-----------|-----|
| **S3 Bucket** | Buckets de almacenamiento S3 | `modules/catalog/storage/s3-bucket/` | [README del módulo S3](./aws-deploy/terraform/modules/catalog/storage/s3-bucket/README.md).


---

## Validación y Testing

### Pipelines de Validación

Los pipelines de validación se encuentran en `aws-deploy/terraform/pipelines/`:

- **validate.yml** - Valida sintaxis y estructura de ConfigFile y Tags
- **deploy.yml** - Ejecuta el despliegue de infraestructura en AWS

### Validadores de Módulos

Scripts Python en `aws-deploy/terraform/pipelines/validators/` para validar módulos por categoría:

```
validators/
├── __init__.py
├── base.py               # Validador base
├── main.py               # Orquestador
└── modules/
    ├── compute.py        # Valida módulos de compute
    ├── databases.py      # Valida módulos de databases
    ├── messaging.py      # Valida módulos de messaging
    ├── networking.py     # Valida módulos de networking
    ├── security.py       # Valida módulos de security
    └── storage.py        # Valida módulos de storage
```

---

## Troubleshooting 

### Quality Gate Falla
- Verificar que el projectKey sea correcto
- Revisar en SonarQube si existen condiciones de calidad pendientes
- Consultar cobertura de código y deuda técnica

### Tests No Se Detectan
- **Go**: Asegurar que los tests sigan patrón `*_test.go`
- **Node**: Generar `coverage/lcov.info` correctamente
- **Python**: Generar `coverage.xml` con herramienta como `coverage`
- **C#**: Ejecutar tests con colector de cobertura XPlat

### Cobertura No Se Importa
- Verificar ruta del reporte de cobertura en extraProperties
- Confirmar que el formato sea compatible (OpenCover para C#, LCOV para Node, XML para Python)

### Errores en Terraform
- Consultar logs del pipeline de validación

---

## Known Issues & Improvement Opportunities

### 🔴 Critical

1. **Inverted condition in `ci-pipeline.yml`**
   - La condición para saltar tests en C# está invertida
   - Cambiar: `contains('cs', parameters.language)` → `ne(parameters.language, 'cs')`

2. **Templates sin parámetros declarados (`ci/build/`)**
   - `ci/build/ecs/main.yml` y `ci/build/eks/main.yml` referencian parámetros sin declararlos

3. **Duplicate task en `ci/semgrep/main.yml`**
   - La última tarea "Check SARIF Artifact" se ejecuta sin condición

### 🟠 Structural

4. **`ci/sonar/java/analysis.yml` - Parámetros incompletos**
   - `work_path` y `repo_name` no se usan
   - Faltan propiedades de SonarQube: `sonar.projectKey`, `sonar.sources`

5. **`work_path` ignorado en tareas Gradle**
   - No se pasa como `workingDirectory` en tareas Gradle

6. **`ci/gitleaks/main.yml` - Implementación stub**
   - Solo imprime variables, no ejecuta análisis real

7. **Double `if` en `ci/sonar/main.yml`**
   - Usar `if/else` en lugar de dos condiciones `if`

8. **`customBreaker` no rompe el build**
   - No ejecuta `exit 1` cuando se detectan problemas

### 🟡 Design Inconsistencies

9. **Variables de runtime sin parámetros declarados**
   - Múltiples templates dependen de variables no declaradas explícitamente

10. **Nombre del servicio SonarQube hardcodeado**
    - `sonar_svc: 'SonarQube-v25.9.0.112764'` debería ser una variable

11. **SonarQube Quality Gate API sin autenticación**
    - `curl` call no incluye token de autenticación

12. **Templates comentadas sin criterio**
    - `initial_config`, `gitleaks`, `customBreaker` están comentadas

### 🔵 Minor

13. `npm install --force` → usar `npm ci`
14. JDK path hardcodeado `/usr/lib/jvm/java-17-amazon-corretto.x86_64/`
15. Mensajes en español en scripts
16. Parseador JSON de Lambda con `grep`/`sed` → usar `jq`
17. Response de Lambda registrada en stdout antes de parsear
18. Python 3.10 hardcodeado en `semgrep/main.yml`

---

## Contribute

Para contribuir al repositorio:
1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add: some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

**Última actualización:** Mayo 2026