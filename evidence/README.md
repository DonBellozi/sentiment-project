# Доказательства выполнения

Актуальные журналы: docker-build-1.0.1.log, docker-layer-size-1.0.1.log, docker-api-1.0.1.log, docker-startup-1.0.1.log, docker-prometheus-1.0.1.txt, ingress-balance.log, hpa-watch.log, monitoring-install.log, monitoring-status.log, kubernetes-current.log.

screenshots/ содержит реальные снимки, переданные автором в процессе выполнения. Они показывают запуск кластера, три Pod, Ingress, увеличение/сокращение реплик, Grafana и Prometheus Targets. Они не являются сгенерированными иллюстрациями.

Первый неуспешный kubernetes-deployment.log находится в history/evidence/. Он относится к моменту до исправления пути и не подтверждает конечное состояние. Старые локальные журналы относятся к Java на хосте; контейнерные результаты имеют префикс docker-.

Измерения Grafana оценены по снимку. Исходные временные ряды окна опыта в архив не экспортировались. Полный отчёт и пояснения ограничений находятся в deliverables/.
