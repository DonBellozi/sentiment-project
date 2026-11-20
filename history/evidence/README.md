# Доказательства
В комплекте нет скриншотов работающего Kubernetes: кластер здесь не запускался.
local-tests.log и local-smoke.json, если присутствуют, относятся только к Java на хосте.
После развёртывания сохраните настоящие снимки:
01-install.png — версии Docker, Minikube, kubectl, Helm и команда установки;
02-nodes.png — minikube status и kubectl get nodes;
03-image.png — Dockerfile, успешная сборка и docker image inspect;
04-api.png — запросы hello / bad / unknown и ответы;
05-workloads.png — 3 Ready Pod, svc, ingress, hpa;
06-ingress.png — ответ через Ingress с Host: sentiment.local;
07-prometheus.png — Targets UP для sentiment и запрос up;
08-grafana.png — шесть панелей с данными под нагрузкой;
09-hpa.png — HPA до/во время/после нагрузки, время наблюдения;
10-balance.png — несколько разных pod в независимых HTTP-соединениях.
Скриншоты терминала должны показывать команду, контекст и полный результат.
