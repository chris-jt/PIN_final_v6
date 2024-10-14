# Proyecto de Despliegue en AWS EKS

Este proyecto implementa un pipeline de CI/CD para desplegar una instancia EC2 en AWS, crear un cluster EKS, y desplegar una aplicación Nginx junto con herramientas de monitoreo (EFK stack y Prometheus/Grafana).

La version 6 implementa el chequeo de la infraestructura para implementar solo los cambios en los pods en caso de ya existir las instancia EC2 y el cluster.

Ademas, se puede seleccionar la rama a deployar

## Estructura del Proyecto

├── .github
│   └── workflows
│       └── main.yaml
├── cloudformation
│   └── ec2-stack.yaml
├── kubernetes
│   ├── elasticsearch.yaml
│   ├── fluentd-configmap.yaml
│   ├── fluentd-daemonset.yaml
│   ├── fluentd-rbac.yaml
│   ├── fkibana.yaml
│   ├── nginx-index-html-configmap.yaml
│   ├── nginx-deployment.yaml
│   ├── nginx-service.yaml
├── scripts
│    └── deploy-efk.sh
├── ec2_user_data.sh
└── README.md

## Funcionamiento

1. El workflow de GitHub Actions se activa manualmente.
2. Se crea una instancia EC2 utilizando CloudFormation.
3. Se configura la instancia EC2 con las herramientas necesarias (Docker, kubectl, eksctl, etc.).
4. Se crea un cluster EKS en AWS.
5. Se despliega un pod de Nginx con una página personalizada.
6. Se despliega el stack EFK (Elasticsearch, Fluentd, Kibana) para monitoreo de logs.
7. Se despliega Prometheus y Grafana para métricas y visualización.

## Acceso a la Instancia EC2

Para acceder a la instancia EC2 desde una PC remota:

1. Descargar la clave SSH `jenkins.pem` del artefacto generado por el workflow.
2. Abrir una terminal y navegar hasta el directorio donde se guardo la clave.
3. Cambiar los permisos de la clave:

        chmod 400 jenkins.pem

4. Conectar a la instancia EC2 usando el comando:

        ssh -i jenkins.pem ubuntu@`<EC2_PUBLIC_IP>

    Reemplazar`<EC2_PUBLIC_IP>` con la IP pública de la instancia EC2 que se encuentra en el archivo `connection_info.txt`.

## Conexión al Cluster EKS

Para conectar al cluster EKS desde la instancia EC2:

1. Una vez conectado a la instancia EC2, el archivo kubeconfig ya debería estar configurado.
2. Se puede verificar la conexión con:

        kubectl get nodes

## Integración con Lens

Para integrar el cluster con Lens desde tu PC remota:

1. Instalar Lens en tu PC.
2. Usar el archivo kubeconfig descargado del artefacto de GitHub Actions.
3. En Lens, añadir un nuevo cluster usando este archivo kubeconfig.

## Acceso a Kibana y Grafana

Las URLs para acceder a Kibana y Grafana se encuentran en el archivo `connection_info.txt`. Estas interfaces son accesibles desde fuera del cloud para monitorear los logs y métricas de la aplicación.

## Conexión al Pod de Nginx desde una PC Remota

Para conectar directamente al pod de Nginx desde tu PC remota:

1. Descargar el archivo kubeconfig del artefacto generado por el workflow de GitHub Actions.
2. Guardar el archivo kubeconfig en tu PC local, por ejemplo, en `~/eks-kubeconfig`.
3. Instalar kubectl en la PC local.
4. Configurar la variable de entorno KUBECONFIG para usar el archivo descargado:

        export KUBECONFIG=~/eks-kubeconfig

5. Verificar la conexion al cluster:

        kubectl get nodes

6. Obtener el nombre del pod de Nginx:

        kubectl get pods -l app=nginx

7. Para conectar directamente al pod de Nginx, se usa el siguiente comando:

        kubectl exec -it `<nombre-del-pod-nginx>` -- /bin/bash

    Reemplazar `<nombre-del-pod-nginx>` con el nombre real del pod del paso anterior.

8. Para ver los logs del pod de Nginx:

        kubectl logs `<nombre-del-pod-nginx>`

    Nota: Asegurar de tener las credenciales de AWS configuradas correctamente en la PC local para poder acceder al cluster EKS.

## Acceso a Kibana:

- Abrir un navegador web y acceda a la URL de Kibana proporcionada en el archivo `connection_info.txt`.

Verificar que Fluentd esté funcionando correctamente:
    kubectl get pods -n kube-system | grep fluentd
    kubectl logs -n kube-system -l k8s-app=fluentd-logging

Verificar que Elasticsearch esté recibiendo datos:
    kubectl exec -it $(kubectl get pods -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}') -- curl -X GET "localhost:9200/_cat/indices?v"

### Configuración inicial de Kibana:

- En la página de inicio de Kibana, ir a "Stack Management" en el menú lateral.
- Clic en "Index Patterns" bajo la sección "Kibana".
- Clic en "Create index pattern".

### Creación del índice para los logs de Nginx:

- En el campo "Index pattern name", ingresar "logstash-*".
- Clic en "Next step".
- En "Time field", seleccionar "@timestamp".
- Clic en "Create index pattern".

### Visualización de logs:

- En el menú lateral de Kibana, ir a "Discover".
- Seleccionar el índice que se acaba de crear.
- Se ve una lista de logs recopilados por Fluentd de todos los pods, incluido el pod de Nginx.

### Filtrado de logs de Nginx:

- En la barra de búsqueda en la parte superior, ingresar `kubernetes.container_name: nginx` para filtrar solo los logs del pod de Nginx.

### Creación de un dashboard para Nginx:

- Ir a "Dashboard" en el menú lateral y hacer clic en "Create dashboard".
- Clic en "Create visualization".
- Seleccionar "Lens" para crear una visualización fácilmente.
- Arrastrar el campo "log" al área de visualización para ver un resumen de los logs.
- Guardar la visualización y añádirla al dashboard.

### Configuración de alertas (opcional):

- Ir a "Stack Management" > "Rules and Connectors".
- Crear una nueva regla basada en los logs de Nginx para recibir alertas sobre eventos específicos.

## Configuración y uso de Grafana para monitoreo del cloud y los pods

1. Acceso a Grafana:

1. Abrir un navegador web y acceder a la URL de Grafana proporcionada en el archivo `connection_info.txt`.
2. Iniciar sesión con las credenciales predeterminadas (usuario: admin, contraseña: admin).
3. Cambiar la contraseña cuando se solicite.

### Configuración de fuente de datos:

1. En el menú lateral de Grafana, ir a "Configuration" > "Data Sources".
2. Clic en "Add data source" y seleccionar "Prometheus".
3. En el campo "URL", ingresar la URL de Prometheus (http://`<EC2_IP>`:8080).
4. Clic en "Save & Test" para verificar la conexión.

### Importación de dashboards predefinidos:

1. En el menú lateral, ir a "Create" > "Import".
2. Ingresar el ID '3119' para importar un dashboard de Kubernetes cluster monitoring.
3. Seleccionar Prometheus como la fuente de datos y haga clic en "Import".

### Creación de un dashboard personalizado para el pod de Nginx:

1. Ir a "Create" > "Dashboard".
2. Clic en "Add new panel".
3. En la consulta, use métricas como `container_cpu_usage_seconds_total{container="nginx"}` para CPU o `container_memory_usage_bytes{container="nginx"}` para memoria.
4. Ajustar el panel según necesidades y guardar.

### Monitoreo del cloud (nodos de Kubernetes):

1. Importar el dashboard con ID 315 para monitoreo de nodos de Kubernetes.
2. Este dashboard proporcionará información sobre el uso de recursos a nivel de nodo.

## Limpieza de recursos en AWS

Para limpiar todos los recursos generados en AWS, ejecuta los siguientes comandos:

1. Eliminar el cluster EKS:

    eksctl delete cluster --name cluster-PIN --region us-east-1

2. Eliminar el stack de CloudFormation:

    aws cloudformation delete-stack --stack-name jenkins-ec2-stack --region us-east-1

3. Esperar a que se complete la eliminación del stack:

    aws cloudformation wait stack-delete-complete --stack-name jenkins-ec2-stack --region us-east-1
