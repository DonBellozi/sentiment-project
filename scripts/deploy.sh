#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
cd "$PROJECT_DIR"
mkdir -p evidence
exec > >(tee -a evidence/deploy-linux.log) 2>&1
date -Is
command -v docker
command -v /usr/local/bin/minikube
command -v /usr/local/bin/helm
docker info >/dev/null
as_cluster_user /usr/local/bin/minikube start -p "$PROFILE" --driver=docker --cpus=4 --memory=8192 --nodes=2 --kubernetes-version=v1.37.0
mk addons enable ingress
mk addons enable metrics-server
docker build --progress=plain -t "$IMAGE" .
size=$(docker history --human=false --format '{{.Size}}' "$IMAGE" | awk '{gsub(/[^0-9]/, ""); total += $0} END {printf "%.0f",total}')
printf 'Uncompressed layers: %s bytes
' "$size"
if [ "$size" -ge 150000000 ]; then echo 'Image exceeds limit'; exit 1; fi
mk image load "$IMAGE"
# Манифест содержит тег 1.0.1. При IMAGE с другим тегом измените его до запуска.
k apply -f "$PROJECT_DIR/k8s/app.yaml"
k -n sentiment rollout status deployment/sentiment --timeout=300s
h repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
h repo update
chart_args=()
if [ -n "${CHART_VERSION:-}" ]; then chart_args=(--version "$CHART_VERSION"); fi
h upgrade --install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f "$PROJECT_DIR/monitoring/values.yaml" "${chart_args[@]}" --wait --timeout 15m
k apply -f "$PROJECT_DIR/monitoring/servicemonitor.yaml" -f "$PROJECT_DIR/monitoring/dashboard-configmap.yaml"
h list -n monitoring -o yaml > evidence/helm-releases.yaml
k -n sentiment get pods,svc,ingress,hpa -o wide
