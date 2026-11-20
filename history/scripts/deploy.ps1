$ErrorActionPreference = 'Stop'
function Check { if ($LASTEXITCODE -ne 0) { throw "Previous command failed: $LASTEXITCODE" } }
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force evidence | Out-Null
Start-Transcript evidence/deploy.log
try {
 minikube start -p sentiment --driver=docker --cpus=4 --memory=8192 --nodes=2; Check
 minikube -p sentiment addons enable ingress; Check
 minikube -p sentiment addons enable metrics-server; Check
 docker build -t sentiment-api:1.0.0 .; Check
 $bytes = [long](docker image inspect sentiment-api:1.0.0 --format '{{.Size}}'); Check
 Write-Output "Image size: $bytes bytes"
 if ($bytes -ge 150000000) { throw 'Image exceeds 150 MB' }
 minikube -p sentiment image load sentiment-api:1.0.0; Check
 kubectl --context=sentiment apply -f k8s/app.yaml; Check
 kubectl --context=sentiment -n sentiment rollout status deployment/sentiment --timeout=240s; Check
 helm repo add prometheus-community https://prometheus-community.github.io/helm-charts; Check
 helm repo update; Check
 helm upgrade --install prometheus prometheus-community/kube-prometheus-stack --kube-context sentiment -n monitoring --create-namespace -f monitoring/values.yaml --wait --timeout 15m; Check
 kubectl --context=sentiment apply -f monitoring/servicemonitor.yaml -f monitoring/dashboard-configmap.yaml; Check
 kubectl --context=sentiment get nodes -o wide; Check
 kubectl --context=sentiment -n sentiment get pods,svc,ingress,hpa; Check
 helm list --kube-context sentiment -n monitoring -o yaml | Out-File evidence/helm-releases.yaml
} finally { Stop-Transcript }
