#!/bin/bash
set -x

# Variables de entorno
echo "Cluster Name: $CLUSTER_NAME"
echo "AWS Region: $AWS_REGION"
echo "Node Type: $NODE_TYPE"
echo "Node Count: $NODE_COUNT"

# Función para esperar a que apt esté disponible
wait_for_apt() {
  while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
    echo "Esperando a que otras operaciones de apt terminen..."
    sleep 5
  done
}
# Función para logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> /home/ubuntu/logfile.log
}

# Función para manejar errores
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Función para comprobar si el cluster EKS existe
cluster_exists() {
    eksctl get cluster --name $CLUSTER_NAME --region $AWS_REGION &> /dev/null
    return $?
}

# Función para actualizar el cluster EKS
update_cluster() {
    log "Actualizando el cluster EKS..."
    eksctl upgrade cluster --name $CLUSTER_NAME --region $AWS_REGION --approve || handle_error "No se pudo actualizar el cluster EKS"
}

# Instalar herramientas solo si no están instaladas
install_if_not_exists() {
    if ! command -v $1 &> /dev/null; then
        log "Instalando $1..."
        $2
    else
        log "$1 ya está instalado, omitiendo instalación."
    fi
}

# Actualizar el sistema
log "Actualizando el sistema..."
sudo apt-get update && sudo apt-get upgrade -y || handle_error "No se pudo actualizar el sistema"

echo "INSTALANDO Unzip"
wait_for_apt
sudo apt-get update
sudo apt-get install -y unzip
unzip -v

# Instalar dependencias
log "INSTALANDO dependencias..."
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common || handle_error "No se pudieron instalar las dependencias"

# Instalar Docker
install_if_not_exists docker "sudo sh get-docker.sh || handle_error 'No se pudo instalar Docker'"

# Instalar Docker Compose
install_if_not_exists docker-compose "sudo curl -L 'https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)' -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose"

# Instalar kubectl
install_if_not_exists kubectl "curl -LO 'https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl' && sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl"

# Instalar eksctl
install_if_not_exists eksctl "curl --silent --location 'https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz' | tar xz -C /tmp && sudo mv /tmp/eksctl /usr/local/bin"

# Instalar AWS CLI
install_if_not_exists aws "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip' && unzip awscliv2.zip && sudo ./aws/install"

# Instalar aws-iam-authenticator
install_if_not_exists aws-iam-authenticator "curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator && chmod +x ./aws-iam-authenticator && sudo mv ./aws-iam-authenticator /usr/local/bin"

# Crear o actualizar cluster EKS
if cluster_exists; then
    log "El cluster EKS ya existe. Comprobando si necesita actualización..."
    update_cluster
else
    log "Creando cluster EKS..."
    eksctl create cluster \
      --name $CLUSTER_NAME \
      --version 1.30 \
      --region $AWS_REGION \
      --nodegroup-name PIN-nodes \
      --node-type $NODE_TYPE \
      --nodes $NODE_COUNT \
      --nodes-min 1 \
      --nodes-max 4
fi    
  
log "Configurando kubectl..."
log "Configurando kubectl para el nuevo cluster..."
if ! aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION; then
    log "Error al actualizar kubeconfig"
    exit 1
fi
log "Contenido de kubeconfig:"
cat ~/.kube/config | while read line; do log "$line"; done
log "Versión de kubectl:"
kubectl version --client | while read line; do log "$line"; done

# Verificar que los nodos estén listos
log "Verificando que los nodos estén listos..."
kubectl get nodes --watch &
PID=$!
sleep 60
kill $PID

log "Versión de AWS CLI:"
aws --version

log "Probando conexión al cluster:"
if ! kubectl get nodes; then
    log "Error al conectar con el cluster"
    exit 1
fi

log "Configuración completada. El cluster EKS está listo para usar."

log "Instalando Helm"
# Instalar Helm
install_if_not_exists helm "curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash"

# Asegurarse de que las configuraciones estén disponibles para el usuario ubuntu
mkdir -p /home/ubuntu/.kube
mkdir -p /root/.kube
sudo sudo cp /root/.kube/config /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Añadir kubectl al PATH del usuario ubuntu
log 'export PATH=$PATH:/usr/local/bin' >> /home/ubuntu/.bashrc
source /home/ubuntu/.bashrc

aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION

log "Configuración del cluster EKS completada."
log "Todas las herramientas necesarias han sido instaladas y el cluster está listo."