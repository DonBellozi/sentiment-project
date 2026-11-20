#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${PROFILE:-sentiment}"
CLUSTER_USER="${CLUSTER_USER:-bell}"
IMAGE="${IMAGE:-sentiment-api:1.0.1}"
as_cluster_user() {
  if [ "$(id -u)" -eq 0 ]; then
    local cluster_home
    cluster_home="$(getent passwd "$CLUSTER_USER" | cut -d: -f6)"
    test -n "$cluster_home"
    runuser -u "$CLUSTER_USER" -- env HOME="$cluster_home" "$@"
  else
    "$@"
  fi
}
mk() { as_cluster_user /usr/local/bin/minikube -p "$PROFILE" "$@"; }
k() { mk kubectl -- "$@"; }
h() { as_cluster_user /usr/local/bin/helm --kube-context "$PROFILE" "$@"; }
