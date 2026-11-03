#!/bin/sh
# Deploy todo-front, todo-store (Docker Hub alainpham/* images) and the traffic generator to the current kubectl context.
# Usage: ./deploy-dockerhub.sh            deploy everything
#        ./deploy-dockerhub.sh --no-traffic   skip todo-front/k8s/traffic.yaml
set -eu

cd "$(dirname "$0")"

traffic=true
[ "${1:-}" = "--no-traffic" ] && traffic=false

echo "==> Context: $(kubectl config current-context)"

# Namespace is created here rather than in a manifest, so `kubectl delete -f` never removes it
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f todo-front/k8s/deployment-dockerhub.yaml
kubectl apply -f todo-store/k8s/deployment-dockerhub.yaml
kubectl -n apps rollout status deploy/todo-store --timeout=120s
kubectl -n apps rollout status deploy/todo-front --timeout=120s

if [ "$traffic" = true ]; then
  kubectl apply -f todo-front/k8s/traffic.yaml
  kubectl -n apps rollout status deploy/todo-front-traffic --timeout=60s
fi

# imagePullPolicy is Always: restart so re-pushed tags are pulled even when the manifests are unchanged
kubectl -n apps rollout restart deploy/todo-store deploy/todo-front
kubectl -n apps rollout status deploy/todo-store --timeout=120s
kubectl -n apps rollout status deploy/todo-front --timeout=120s

kubectl -n apps get pods -o wide
