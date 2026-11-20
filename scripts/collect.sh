#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/common.sh"
cd "$PROJECT_DIR"
mkdir -p evidence
stamp=$(date +%Y%m%d-%H%M%S)
# Сохраняйте ошибки диагностики, но не прерывайте оставшиеся чтения.
{
 date -Is
 cat /etc/os-release
 nproc
 free -h
 df -h /
 docker version
 mk version
 h version --short
 h list -n monitoring -o yaml
 k get nodes -o wide
 k -n sentiment get pods,svc,ingress,hpa -o wide
 k -n sentiment top pods
 k -n monitoring get pods,servicemonitor
 docker image inspect "$IMAGE" --format 'Image={{.RepoTags}} StoredSize={{.Size}}'
 docker history --human=false --format '{{.Size}}' "$IMAGE" | awk '{gsub(/[^0-9]/, ""); total += $0} END {printf "Uncompressed layers: %.0f bytes
",total}'
 k -n sentiment get events --sort-by=.lastTimestamp
} > "evidence/diagnostics-$stamp.log" 2>&1 || true
printf 'Saved evidence/diagnostics-%s.log
' "$stamp"
