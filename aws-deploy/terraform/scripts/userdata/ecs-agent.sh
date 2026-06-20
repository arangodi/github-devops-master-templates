#!/bin/bash
# =============================================================================
# ECS Agent Installation Script
# =============================================================================
# Instala y configura el agente de Amazon ECS en una instancia EC2 con
# Amazon Linux 2023, permitiendo que la instancia se registre en un cluster
# ECS y pueda ejecutar tasks con launch_type: EC2.
#
# Variables inyectadas por Terraform via templatefile():
#   - cluster_name: Nombre completo del cluster ECS (resuelto por el engine)
#
# Uso en config.yml:
#   ec2_instances:
#     - name: worker-host
#       os_type: linux
#       instance_type: t3.large
#       enable_ssm: true
#       ecs_cluster_name: cluster    
# =============================================================================

#!/bin/bash
LOG_FILE="/var/log/ecs-agent-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "============================================"
echo "ECS Agent Setup - $(date)"
echo "Cluster: ${cluster_name}"
echo "============================================"

# 1. Escribir config
echo "[1/3] Escribiendo configuración..."
mkdir -p /etc/ecs

cat > /etc/ecs/ecs.config << EOF
ECS_CLUSTER=${cluster_name}
ECS_ENABLE_TASK_IAM_ROLE=true
ECS_ENABLE_TASK_IAM_ROLE_NETWORK_HOST=true
ECS_ENABLE_CONTAINER_METADATA=true
ECS_LOGLEVEL=info
ECS_LOGFILE=/var/log/ecs/ecs-agent.log
ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true
ECS_EXEC_ENABLED=true
EOF

# 2. Pre-descargar imagen correcta que usa el agente internamente
echo "[2/3] Descargando imagen del agente ECS..."
docker pull amazon/amazon-ecs-agent:latest

# 3. Ejecutar pre-start para preparar el entorno
echo "[3/3] Iniciando agente ECS..."
/usr/libexec/amazon-ecs-init pre-start
/usr/libexec/amazon-ecs-init start &

sleep 15

if docker ps | grep -q ecs-agent; then
  echo "✅ Agente ECS corriendo correctamente"
else
  echo "⚠️  Revisar: docker ps -a"
fi

echo "Setup completado: $(date)"