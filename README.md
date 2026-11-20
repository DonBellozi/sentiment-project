# SentimentOps

Учебный Java API анализа тональности в Minikube. Развертывание проверено 15–16 ноября 2026 года на Ubuntu Server 24.04.3 LTS в VM ESXi. Два узла Ready, три Pod, HTTP 200 через Ingress и LoadBalancer, HPA 3 → 6 → 3, Grafana и три Actuator Targets UP подтверждены реальными материалами в `evidence/`.

## Реализованный вариант

Spring Boot 3.5.7, Java 17, Actuator и Micrometer. `GET /api/sentiment?text=hello` возвращает `sentiment`, `model` и `pod`. `lexicon-v1` — разрешенный заданием словарный mock, не обученная нейросеть. Регистр игнорируется; проверяются целые буквенные слова. Отрицания и сарказм не распознаются; качество на тестовом корпусе не измерялось. HTTP 400 при пропущенном, пробельном и слишком длинном text (>4000).

## Среда и версии

VM: 8 vCPU, около 23 GiB RAM; корневой раздел 78 GiB. Docker Engine 29.9.3; Minikube 1.39.0; Kubernetes 1.37.0; Helm 4.3.2. Два узла получают по 4 CPU и 8192 MB RAM. Оба находятся на одном физическом хосте; испытания отказа ESXi не выполнялись.

Версия Helm chart в исходных журналах не зафиксирована. Перед повторным развертыванием выберите версию и передайте `CHART_VERSION=...`; `deploy.sh` запишет результат в `evidence/helm-releases.yaml`. Скрипты Linux подготовлены по выполненным командам, но целиком на новой чистой VM после сборки этого комплекта не запускались. Не выдавайте их наличие за отдельное повторное испытание.

## Установка инструментов

Docker Engine устанавливается из официального apt-репозитория по https://docs.docker.com/engine/install/ubuntu/ . Пользователь bell должен иметь доступ к Docker (группа docker; затем новый сеанс).

Зафиксированную версию Minikube можно установить под root:

```bash
curl -fL https://github.com/kubernetes/minikube/releases/download/v1.39.0/minikube-linux-amd64 -o /tmp/minikube-sentiment
install -m 0755 /tmp/minikube-sentiment /usr/local/bin/minikube
```

Helm: https://helm.sh/docs/intro/install/ . В проверенной среде использован Helm 4.3.2. Для команд kubectl проект использует совместимую версию, которую предоставляет `minikube kubectl --`.

## Сборка и развертывание

Из корня проекта под root (для другого пользователя кластера задайте `CLUSTER_USER`):

```bash
bash scripts/deploy.sh
bash scripts/collect.sh
```

Абсолютный путь приведен для фактической VM. При другом размещении измените его. `runuser -l` меняет текущий каталог, поэтому относительные пути в переданной ему строке не подходят. `scripts/common.sh` передает аргументы отдельно и использует абсолютные пути проекта.

## Размер контейнера

Образ 1.0.1: **94 334 976 байт (94,33 MB)** распакованных слоев. Файл `evidence/docker-layer-size-1.0.1.log`. Это меньше 150 000 000 байт. В Docker 29 containerd store `.Size` учитывает сжатое и распакованное хранение вместе; это другой показатель: https://docs.docker.com/engine/storage/containerd/ . Для требования использована сумма слоев из `docker history --human=false`. Скрипт проверяет тот же показатель. Не сравнивайте размер JAR с размером образа.

Тег образа 1.0.1 включает `jdk.management`, устранивший предупреждение о GC metrics. Maven-версия JAR остается 1.0.0. Тесты Maven выполнялись в первой сборке; при пересборке измененного runtime слой тестов был кеширован.

## Доступ через Ingress

В Ubuntu VM:

```bash
curl -i -H 'Host: sentiment.local' 'http://192.168.49.2/api/sentiment?text=hello'
```

Ingress маршрутизирует `/api` на Service sentiment:80. Для нового профиля IP может отличаться: проверьте `minikube -p sentiment ip`. Журнал `evidence/ingress-balance.log` содержит 15 ответов трех Pod (7/5/3); равномерность на большой выборке не измерялась.

## Доступ через LoadBalancer

В отдельном окне под root:

```bash
MINIKUBE_HOME=/home/bell KUBECONFIG=/home/bell/.kube/config /usr/local/bin/minikube -p sentiment tunnel
```

Оставьте окно открытым. В другом окне VM:

```bash
runuser -l bell -c '/usr/local/bin/minikube -p sentiment kubectl -- -n sentiment get svc sentiment'
curl -i 'http://10.107.117.240/api/sentiment?text=hello'
```

Адрес относится к фактическому профилю; при новом создании возьмите EXTERNAL-IP из вывода. Доступ проверен с VM, не напрямую с Windows. Без работающего tunnel ожидается pending. Если найден другой tunnel, сначала определите его процесс и штатно остановите конкретный экземпляр. Не запускайте несколько туннелей.

## Grafana и Prometheus

В отдельных окнах VM:

```bash
runuser -l bell -c '/usr/local/bin/minikube -p sentiment kubectl -- -n monitoring port-forward --address 100.127.255.81 svc/prometheus-grafana 3000:80'
runuser -l bell -c '/usr/local/bin/minikube -p sentiment kubectl -- -n monitoring port-forward --address 100.127.255.81 svc/prometheus-kube-prometheus-prometheus 9090:9090'
```

Откройте Grafana на http://100.127.255.81:3000 и Prometheus на http://100.127.255.81:9090/targets . У нового стенда адрес VM и имена Service могут отличаться; проверьте `get svc -n monitoring`. Вход Grafana — admin, пароль берется из Secret локально и не включается в комплект.

Дашборд `Sentiment API Overview` импортируется ConfigMap и sidecar. ServiceMonitor выбирает внутренний Service на 8081. В Prometheus подтверждены три UP по `/actuator/prometheus`. У системных scheduler, controller-manager и etcd обнаружен connection refused; их мониторинг не настроен полностью. Alertmanager отключен, retention метрик 6 часов, постоянные тома для сохранения истории не настроены. Port-forward требует работающего процесса; после его остановки веб-доступ пропадает.

## Нагрузочная проверка HPA

```bash
runuser -l bell -c '/usr/local/bin/minikube -p sentiment kubectl -- apply -f /home/bell/sentimentops/sentiment-project/k8s/load.yaml'
runuser -l bell -c '/usr/local/bin/minikube -p sentiment kubectl -- -n sentiment get hpa -w'
```

Fortio: 64 соединения, 300 секунд, QPS без ограничения. Наблюдайте до и после нагрузки. Старый Job удаляется автоматически через TTL; для немедленного повтора сначала сохраните его logs, затем удалите именно `job/sentiment-load` и примените YAML заново. Ctrl+C останавливает наблюдение, а не Deployment. HPA: CPU 60% от requests 100m, 3–6 реплик, стабилизация scaleDown 120 секунд. Реально зафиксирован цикл 3 → 6 → 3. Точные задержки реакции и предел производительности статистически не измерялись.

На снимке Grafana пик около 9 тыс. RPS, CPU около 2,4 cores, p95 около 0,97–1,09 мс. Это чтение изображения одного опыта, не гарантия. p95 — серверная метрика. `No data` у 5xx не доказывает отсутствие ошибок.

## Материалы и публикация

`deliverables/` содержит новый отчет на 10 страниц, аналитическое приложение на 11 страниц (10 содержательных и источники) и презентацию на 14 слайдов. Титульный лист не включен. `evidence/screenshots/` — реальные снимки. Исторические исходные документы и первый неуспешный журнал находятся в `history/`; их нельзя выдавать за актуальный результат.

В комплекте подготовлена локальная история Git. Публичный удаленный репозиторий еще не создан и ссылка не предоставлена. Перед отправкой ментору опубликуйте проект в выбранном Git-сервисе и добавьте реальный URL в этот README и материалы. Архив не содержит kubeconfig, паролей и ключей.

## Источники

Пять статей и официальная документация перечислены в отчете и аналитическом приложении; дата обращения 16 ноября 2026 года. Числа исследований не выдаются за локальные измерения.
