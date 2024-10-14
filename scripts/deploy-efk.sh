#!/bin/bash

# Aplicar la configuración de Elasticsearch
kubectl apply -f elasticsearch.yaml

# Esperar a que Elasticsearch esté listo
echo "Esperando a que Elasticsearch esté listo..."
kubectl wait --for=condition=ready pod -l app=elasticsearch --timeout=300s

# Aplicar la configuración de Fluentd
kubectl apply -f fluentd-configmap.yaml
kubectl apply -f fluentd-rbac.yaml
kubectl apply -f fluentd-daemonset.yaml

# Aplicar la configuración de Kibana
kubectl apply -f kibana.yaml

# Esperar a que los pods estén listos
kubectl wait --for=condition=ready pod -l app=elasticsearch --timeout=300s
kubectl wait --for=condition=ready pod -l k8s-app=fluentd-logging -n kube-system --timeout=300s
kubectl wait --for=condition=ready pod -l app=kibana --timeout=300s

# Verificar que todos los pods estén en estado Running
kubectl get pods
kubectl get pods -n kube-system | grep fluentd

# Verificar los logs de Fluentd
kubectl logs -n kube-system -l k8s-app=fluentd-logging --tail=20

# Verificar la conectividad entre Fluentd y Elasticsearch
echo "Verificando la conexión entre Fluentd y Elasticsearch..."
FLUENTD_POD=$(kubectl get pods -n kube-system -l k8s-app=fluentd-logging -o jsonpath='{.items[0].metadata.name}')
if [ -n "$FLUENTD_POD" ]; then
  kubectl exec -it $FLUENTD_POD -n kube-system -- curl -sS --retry 10 --retry-delay 5 http://elasticsearch.default.svc.cluster.local:9200
else
  echo "No se encontró el pod de Fluentd"
fi

# Verificar los índices en Elasticsearch
echo "Verificando los índices en Elasticsearch..."
ES_POD=$(kubectl get pods -l app=elasticsearch -o jsonpath='{.items[0].metadata.name}')
if [ -n "$ES_POD" ]; then
  kubectl exec -it $ES_POD -- curl -sS --retry 10 --retry-delay 5 http://localhost:9200/_cat/indices
else
  echo "No se encontró el pod de Elasticsearch"
fi