#!/bin/bash
set -e
 
echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Instalando k3s + ArgoCD v2.11 en Amazon Linux 2023       ║"
echo "╚════════════════════════════════════════════════════════════╝"
 
# Color codes para logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
 
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
 
log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}
 
log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}
 
log_error() {
    echo -e "${RED}[✗]${NC} $1"
}
 
# Actualizar sistema
log_info "Actualizando sistema..."
dnf update -y
dnf upgrade -y
 
# ARREGLO: Usar --allowerasing para resolver conflicto de curl
log_info "Instalando dependencias (resolviendo conflicto de curl)..."
dnf install -y --allowerasing \
    curl \
    wget \
    git \
    vim \
    htop \
    net-tools
 
log_success "Dependencias instaladas"
 
# Desabilitar swap (requerido para K8s)
log_info "Deshabilitando swap..."
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
log_success "Swap deshabilitado"
 
# Instalar k3s
log_info "Instalando k3s..."
curl -sfL https://get.k3s.io | sh -s - \
    --write-kubeconfig-mode 644 \
    --disable traefik \
    --disable servicelb
 
# Esperar a que k3s esté listo
log_info "Esperando a que k3s esté listo..."
for i in {1..30}; do
    if kubectl get nodes &>/dev/null; then
        log_success "k3s está listo"
        break
    fi
    echo -n "."
    sleep 2
done
 
# Configurar kubeconfig para root
log_info "Configurando kubeconfig..."
mkdir -p /root/.kube
cp /etc/rancher/k3s/k3s.yaml /root/.kube/config
chmod 600 /root/.kube/config
export KUBECONFIG=/root/.kube/config
log_success "kubeconfig configurado"
 
# Instalar Helm
log_info "Instalando Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
log_success "Helm instalado"
 
# Crear namespace para ArgoCD
log_info "Creando namespace argocd..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
log_success "Namespace argocd creado"
 
# Instalar ArgoCD v2.11.0 (versión estable, compatible con k3s)
log_info "Instalando ArgoCD ..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.11.0/manifests/install.yaml
 
# Esperar a que ArgoCD esté listo
log_info "Esperando a que ArgoCD esté listo..."
kubectl wait --for=condition=Available -n argocd deployment/argocd-server --timeout=300s || true
 
# Obtener credenciales
log_info "Obteniendo credenciales de ArgoCD..."
sleep 5
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d 2>/dev/null || echo "Error obteniendo contraseña")
 
# Instalar nginx-ingress
log_info "Instalando Nginx Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.0/deploy/static/provider/baremetal/deploy.yaml
log_success "Nginx Ingress instalado"
 
# Instalar cert-manager (opcional)
log_info "Instalando cert-manager (opcional para SSL)..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml || log_warn "cert-manager install falló (opcional)"
 
# Información de acceso
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         ✅ K3S + ARGOCD INSTALADO                  ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
 
log_success "Estado del cluster:"
kubectl get nodes -o wide
echo ""
 
log_success "Pods en ArgoCD:"
kubectl get pods -n argocd
echo ""
 
log_success "Servicios en ArgoCD:"
kubectl get svc -n argocd
echo ""
 
echo "┌────────────────────────────────────────────────────────────┐"
echo "│ 🔐 CREDENCIALES DE ARGOCD                                  │"
echo "├────────────────────────────────────────────────────────────┤"
echo "│ Usuario: admin                                             │"
echo "│ Contraseña: $ARGOCD_PASSWORD"
echo "└────────────────────────────────────────────────────────────┘"
echo ""