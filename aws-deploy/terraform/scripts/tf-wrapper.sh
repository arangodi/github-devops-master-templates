#!/bin/bash

CONFIG_FILE=$1
ACTION=$2
EXTRA_ARGS=""
SERVICE_FILE=""
ONLY_COMPONENT=""

KNOWN_ENGINES=(
  "compute"
  "databases"
  "messaging"
  "networking"
  "security"
  "storage"
)

# Parsea argumentos adicionales
for arg in "${@:3}"; do
  if [[ $arg == --service=* ]]; then
    SERVICE_FILE="${arg#--service=}"
  elif [[ $arg == --only=* ]]; then
    ONLY_COMPONENT="${arg#--only=}"
  else
    EXTRA_ARGS="$EXTRA_ARGS $arg"
  fi
done

# Path absoluto del proyecto
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Convierte CONFIG_FILE a path absoluto si es relativo
if [[ "$CONFIG_FILE" = /* ]]; then
  CONFIG_FILE_ABS="$CONFIG_FILE"
else
  CONFIG_FILE_ABS="$ROOT_DIR/$CONFIG_FILE"
fi

# Infiere account, environment y project del path del config file
ACCOUNT=$(echo "$CONFIG_FILE" | awk -F'/' '{print $(NF-2)}')
ENVIRONMENT=$(echo "$CONFIG_FILE" | awk -F'/' '{print $(NF-1)}')
PROJECT=$(basename "$CONFIG_FILE" .yml)

# También lee del YAML por si se necesita sobreescribir
ACCOUNT=$(yq -r ".account // \"$ACCOUNT\"" "$CONFIG_FILE_ABS")
ENVIRONMENT=$(yq -r ".environment // \"$ENVIRONMENT\"" "$CONFIG_FILE_ABS")
PROJECT_NAME=$(yq -r ".project_name // \"$PROJECT\"" "$CONFIG_FILE_ABS")

STATE_BUCKET="btg.${ENVIRONMENT}.${ACCOUNT}.terraform"
STATE_REGION="us-east-1"
SHARED_PROVIDERS="$ROOT_DIR/engine/shared/providers.tf"

#################################################
# REGISTRA EL SERVICE.YML EN EL DIRECTORIO
#################################################
register_service() {
  if [ -z "$SERVICE_FILE" ]; then
    return 0
  fi

  if [ ! -f "$SERVICE_FILE" ]; then
    echo "❌ service.yml no encontrado: $SERVICE_FILE"
    exit 1
  fi

  SERVICE_NAME=$(yq -r '.name' "$SERVICE_FILE")

  if [ -z "$SERVICE_NAME" ] || [ "$SERVICE_NAME" == "null" ]; then
    echo "❌ El service.yml no tiene el campo 'name'"
    exit 1
  fi

  SERVICES_DIR="$ROOT_DIR/config/$ACCOUNT/services/$ENVIRONMENT/$PROJECT_NAME"
  mkdir -p "$SERVICES_DIR"
  cp "$SERVICE_FILE" "$SERVICES_DIR/${SERVICE_NAME}.yml"

  echo "📋 Servicio '$SERVICE_NAME' registrado en:"
  echo "   $SERVICES_DIR/${SERVICE_NAME}.yml"
}

#################################################
# VERIFICA SI UN STATE EXISTE EN S3
#################################################
state_exists() {
  local STATE_KEY=$1
  aws s3 ls "s3://${STATE_BUCKET}/${STATE_KEY}" > /dev/null 2>&1
  return $?
}

#################################################
# CREA UN STATE VACÍO EN S3 SI NO EXISTE
#################################################
create_empty_state() {
  local STATE_KEY=$1
  
  if ! state_exists "$STATE_KEY"; then
    # Generar UUID para lineage (compatible con sistemas sin uuidgen)
    local LINEAGE
    if command -v uuidgen &> /dev/null; then
      LINEAGE=$(uuidgen)
    else
      # Fallback: generar UUID simple con /dev/urandom
      LINEAGE=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1 | sed -e 's/\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/')
    fi
    
    # Crear state mínimo válido
    cat > /tmp/empty_state_$$.json << EOF
{
  "version": 4,
  "terraform_version": "1.5.0",
  "serial": 1,
  "lineage": "${LINEAGE}",
  "outputs": {},
  "resources": []
}
EOF
    
    aws s3 cp /tmp/empty_state_$$.json "s3://${STATE_BUCKET}/${STATE_KEY}" > /dev/null 2>&1
    local RESULT=$?
    rm -f /tmp/empty_state_$$.json
    
    if [ $RESULT -eq 0 ]; then
      echo "   ✅ ${STATE_KEY}"
      return 0
    else
      echo "   ❌ Error: ${STATE_KEY}"
      return 1
    fi
  fi
  
  return 0
}

#################################################
# DESHABILITA DELETION PROTECTION EN ELBS
#################################################
disable_alb_protection() {
  echo "🔓 Deshabilitando deletion protection en ELBs del proyecto $PROJECT_NAME..."

  ELB_ARNS=$(aws elbv2 describe-load-balancers \
    --region "$STATE_REGION" \
    --query "LoadBalancers[?contains(LoadBalancerName, '${PROJECT_NAME}')].LoadBalancerArn" \
    --output text)

  if [ -z "$ELB_ARNS" ]; then
    echo "   No se encontraron ELBs para el proyecto"
    return 0
  fi

  for ARN in $ELB_ARNS; do
    echo "   → Deshabilitando: $ARN"
    aws elbv2 modify-load-balancer-attributes \
      --region "$STATE_REGION" \
      --load-balancer-arn "$ARN" \
      --attributes Key=deletion_protection.enabled,Value=false > /dev/null
  done

  echo "✅ Deletion protection deshabilitada"
}

#################################################
# RESOLUCION DEL GRAFO DE DEPENDENCIAS
#################################################
resolve_order() {
  local components=($( yq -r '.catalog | keys | .[]' "$CONFIG_FILE_ABS" ))
  local resolved=()
  local unresolved=("${components[@]}")
  local max_iterations=10
  local iteration=0

  while [ ${#unresolved[@]} -gt 0 ]; do

    iteration=$((iteration + 1))
    if [ $iteration -gt $max_iterations ]; then
      echo "❌ Error: dependencia circular detectada entre componentes" >&2
      exit 1
    fi

    local progress=false

    for component in "${unresolved[@]}"; do
      local deps=$(yq -r ".catalog.${component}.depends_on // [] | .[]" "$CONFIG_FILE_ABS")
      local all_deps_resolved=true

      for dep in $deps; do
        if ! printf '%s\n' "${resolved[@]}" | grep -q "^${dep}$"; then
          all_deps_resolved=false
          break
        fi
      done

      if [ "$all_deps_resolved" = true ]; then
        resolved+=("$component")
        unresolved=("${unresolved[@]/$component}")
        unresolved=(${unresolved[@]})
        progress=true
      fi
    done

    if [ "$progress" = false ]; then
      echo "❌ Error: dependencia circular o dependencia no declarada" >&2
      echo "   Componentes sin resolver: ${unresolved[@]}" >&2
      exit 1
    fi

  done

  echo "${resolved[@]}"
}

#################################################
# FUNCION PARA SHARED
#################################################
run_shared() {
  local APPLY_ACTION=${1:-$ACTION}
  local ENGINE_DIR="$ROOT_DIR/engine/shared"
  local STATE_KEY="$ACCOUNT/$ENVIRONMENT/$PROJECT_NAME/shared/terraform.tfstate"

  echo ""
  echo "🔧 ${APPLY_ACTION}: shared/..."
  echo "================================"
  echo "Account:      $ACCOUNT"
  echo "Environment:  $ENVIRONMENT"
  echo "Project:      $PROJECT_NAME"
  echo "Engine:       $ENGINE_DIR"
  echo "Action:       $APPLY_ACTION"
  echo "Bucket:       $STATE_BUCKET"
  echo "State:        $STATE_KEY"
  echo "================================"

  # Limpia cache de módulos
  if [ -d "$ENGINE_DIR/.terraform/modules" ]; then
    rm -rf "$ENGINE_DIR/.terraform/modules"
  fi

  cd "$ENGINE_DIR"

  terraform init -reconfigure \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="region=$STATE_REGION" \
    -backend-config="key=$STATE_KEY" \
    -input=false \
    #-backend-config="use_lockfile=true" 
    

  terraform $APPLY_ACTION \
    -var="config_file=$CONFIG_FILE_ABS" \
    -input=false \
    $EXTRA_ARGS

  local EXIT_CODE=$?
  cd "$ROOT_DIR"
  return $EXIT_CODE
}

#################################################
# FUNCION PARA CATALOG
#################################################
run_catalog() {
  local ENGINE_DIR=$1
  local STATE_KEY=$2
  local APPLY_ACTION=${3:-$ACTION}

  # Copia providers.tf desde engine/ usando path absoluto
  if [ ! -f "$ENGINE_DIR/providers.tf" ] || \
     ! diff -q "$SHARED_PROVIDERS" "$ENGINE_DIR/providers.tf" > /dev/null 2>&1; then
    cp "$SHARED_PROVIDERS" "$ENGINE_DIR/providers.tf"
    echo "📄 providers.tf copiado: $ENGINE_DIR/providers.tf"
  fi

  # Limpia cache de módulos
  if [ -d "$ENGINE_DIR/.terraform/modules" ]; then
    rm -rf "$ENGINE_DIR/.terraform/modules"
  fi

  echo "================================"
  echo "Account:      $ACCOUNT"
  echo "Environment:  $ENVIRONMENT"
  echo "Project:      $PROJECT_NAME"
  echo "Engine:       $ENGINE_DIR"
  echo "Action:       $APPLY_ACTION"
  echo "Bucket:       $STATE_BUCKET"
  echo "State:        $STATE_KEY"
  echo "================================"

  cd "$ENGINE_DIR"

  terraform init -reconfigure \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="region=$STATE_REGION" \
    -backend-config="key=$STATE_KEY" \
    -input=false \
    #-backend-config="use_lockfile=true" 
    

  terraform $APPLY_ACTION \
    -var="config_file=$CONFIG_FILE_ABS" \
    -var="account=$ACCOUNT" \
    -var="environment=$ENVIRONMENT" \
    -var="project_name=$PROJECT_NAME" \
    -var="aws_region=$STATE_REGION" \
    -input=false \
    $EXTRA_ARGS

  local EXIT_CODE=$?
  cd "$ROOT_DIR"
  return $EXIT_CODE
}

#################################################
# INICIALIZAR TODOS LOS STATES VACÍOS
#################################################
initialize_all_states() {
  echo ""
  echo "📝 Inicializando states vacíos para todos los engines conocidos..."
  echo ""

  local CREATED=false

  for COMPONENT in "${KNOWN_ENGINES[@]}"; do
    local STATE_KEY="$ACCOUNT/$ENVIRONMENT/$PROJECT_NAME/$COMPONENT/terraform.tfstate"

    if ! state_exists "$STATE_KEY"; then
      CREATED=true
      create_empty_state "$STATE_KEY"
      if [ $? -ne 0 ]; then
        echo "❌ Error creando state vacío para $COMPONENT/"
        return 1
      fi
    fi
  done

  if [ "$CREATED" = true ]; then
    echo ""
    echo "✅ States vacíos creados exitosamente"
  else
    echo "✅ Todos los states ya existen"
  fi

  return 0
}

#################################################
# LOGICA PRINCIPAL
#################################################

if [ "$ACTION" == "destroy" ]; then

  #################################################
  # DESTROY — orden inverso
  #################################################
  ORDERED_COMPONENTS=$(resolve_order)
  REVERSED_COMPONENTS=$(echo "$ORDERED_COMPONENTS" | tr ' ' '\n' | tac | tr '\n' ' ')

  if [ -n "$ONLY_COMPONENT" ]; then
    REVERSED_COMPONENTS="$ONLY_COMPONENT"
    echo ""
    echo "📋 Destroy solo de: $ONLY_COMPONENT"
  else
    echo ""
    echo "📋 Orden de destroy (inverso): $REVERSED_COMPONENTS"
  fi

  echo ""

  for COMPONENT in $REVERSED_COMPONENTS; do

    ENGINE_DIR="$ROOT_DIR/engine/catalog/$COMPONENT"

    if [ ! -d "$ENGINE_DIR" ]; then
      echo "⚠️  No engine found for component '$COMPONENT', skipping..."
      continue
    fi

    STATE_KEY="$ACCOUNT/$ENVIRONMENT/$PROJECT_NAME/$COMPONENT/terraform.tfstate"

    if ! state_exists "$STATE_KEY"; then
      echo "⚠️  catalog/$COMPONENT sin state — skipping..."
      continue
    fi

    if [ "$COMPONENT" == "networking" ]; then
      disable_alb_protection
    fi

    echo ""
    echo "📦 destroy: catalog/$COMPONENT..."
    run_catalog "$ENGINE_DIR" "$STATE_KEY" "destroy"

    if [ $? -ne 0 ]; then
      echo "❌ Error destruyendo catalog/$COMPONENT — abortando"
      exit 1
    fi

  done

  # Shared siempre de último en destroy
  if state_exists "$ACCOUNT/$ENVIRONMENT/$PROJECT_NAME/shared/terraform.tfstate"; then
    echo ""
    echo "🔧 destroy: shared/..."
    run_shared "destroy"
    if [ $? -ne 0 ]; then
      echo "❌ Error destruyendo shared/"
      exit 1
    fi
  fi

else

  #################################################
  # APPLY — orden normal
  #################################################

  # Registra el service.yml si se pasó --service
  register_service

  # Shared siempre primero para garantizar outputs
  echo ""
  echo "🔧 Inicializando shared/ (apply para garantizar outputs)..."
  run_shared "apply -auto-approve"
  if [ $? -ne 0 ]; then
    echo "❌ Error en shared/ — abortando"
    exit 1
  fi

  #################################################
  # ✨ CREAR STATES VACÍOS PARA TODOS LOS COMPONENTES
  #################################################
  initialize_all_states
  if [ $? -ne 0 ]; then
    echo "❌ Error inicializando states"
    exit 1
  fi

  # Si se especifica --only, solo corre ese componente
  if [ -n "$ONLY_COMPONENT" ]; then
    ORDERED_COMPONENTS="$ONLY_COMPONENT"
    echo ""
    echo "📋 Solo componente: $ONLY_COMPONENT"
  else
    ORDERED_COMPONENTS=$(resolve_order)
    echo ""
    echo "📋 Orden de aplicación resuelto: $ORDERED_COMPONENTS"
  fi

  echo ""

  #################################################
  # EJECUTAR APPLY EN CADA COMPONENTE
  #################################################
  for COMPONENT in $ORDERED_COMPONENTS; do

    ENGINE_DIR="$ROOT_DIR/engine/catalog/$COMPONENT"

    if [ ! -d "$ENGINE_DIR" ]; then
      echo "⚠️  No engine found for component '$COMPONENT', skipping..."
      continue
    fi

    STATE_KEY="$ACCOUNT/$ENVIRONMENT/$PROJECT_NAME/$COMPONENT/terraform.tfstate"

    echo ""
    echo "📦 apply: catalog/$COMPONENT..."
    run_catalog "$ENGINE_DIR" "$STATE_KEY" "apply"

    if [ $? -ne 0 ]; then
      echo "❌ Error en catalog/$COMPONENT — abortando"
      exit 1
    fi

  done

fi
