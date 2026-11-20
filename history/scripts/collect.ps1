$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
New-Item -ItemType Directory -Force evidence | Out-Null
Start-Transcript evidence/verification.log
try {
 kubectl --context=sentiment get nodes -o wide
 kubectl --context=sentiment -n sentiment get pods,svc,ingress,hpa -o wide
 kubectl --context=sentiment -n sentiment top pods
 kubectl --context=sentiment -n monitoring get pods,servicemonitor
 docker image inspect sentiment-api:1.0.0 --format '{{.Size}}'
 kubectl --context=sentiment -n sentiment get events --sort-by=.lastTimestamp
} finally { Stop-Transcript }
