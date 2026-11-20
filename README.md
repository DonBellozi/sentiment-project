# SentimentOps

Учебный Java API анализа тональности в Minikube. Развертывание проверено на Ubuntu Server 24.04.3 LTS в VM ESXi. Два узла Ready, три Pod, HTTP 200 через Ingress и LoadBalancer, HPA 3 → 6 → 3, Grafana и три Actuator Targets UP подтверждены реальными материалами в `evidence/`.

## Реализованный вариант

Spring Boot 3.5.7, Java 17, Actuator и Micrometer. `GET /api/sentiment?text=hello` возвращает `sentiment`, `model` и `pod`. `lexicon-v1` — разрешенный заданием словарный mock, не обученная нейросеть. Регистр игнорируется; проверяются целые буквенные слова. Отрицания и сарказм не распознаются; качество на тестовом корпусе не измерялось. HTTP 400 при пропущенном, пробельном и слишком длинном text (>4000).

## Среда и версии

VM: 8 vCPU, около 23 GiB RAM; корневой раздел 78 GiB. Docker Engine 29.9.3; Minikube 1.39.0; Kubernetes 1.37.0; Helm 4.3.2. Два узла получают по 4 CPU и 8192 MB RAM. Оба находятся на одном физическом хосте; испытания отказа ESXi не выполнялись.

Версия Helm chart в исходных журналах не зафиксирована. Перед повторным развертыванием выберите версию и передайте `CHART_VERSION=...`; `deploy.sh` запишет результат в `evidence/helm-releases.yaml`. Скрипты Linux подготовлены по выполненным командам, но целиком на новой чистой VM после сборки этого комплекта не запускались. Не выдавайте их наличие за отдельное повторное испытание.

## Установка инструментов

Docker Engine устанавливается из официального apt-репозитория по https://docs.docker.com/engine/install/ubuntu/ . Учетная запись владельца профиля должна иметь доступ к Docker (группа docker; затем новый сеанс). В root-сеансе команды ниже сами используют эту учетную запись.

Зафиксированную версию Minikube можно установить под root:

```bash
curl -fL https://github.com/kubernetes/minikube/releases/download/v1.39.0/minikube-linux-amd64 -o /tmp/minikube-sentiment
install -m 0755 /tmp/minikube-sentiment /usr/local/bin/minikube
```

Helm: https://helm.sh/docs/intro/install/ . В проверенной среде использован Helm 4.3.2. Для команд kubectl проект использует совместимую версию, которую предоставляет `minikube kubectl --`.

## Управление

```bash
bash scripts/manage.sh info
bash scripts/manage.sh status
```

`info` покажет выбранный профиль, его владельца и каталог. Скрипт автоматически находит единственную учетную запись с существующим профилем `sentiment`. Имя пользователя не зашито в сценарии: путь выше — только фактическое размещение проекта на нашей VM.

Все команды передаются отдельными аргументами, без сборки строки для login shell. Поэтому относительный каталог не теряется, а пробелы в аргументах сохраняются. Для YAML сценарии используют абсолютный путь от расположения проекта.

| Действие | Команда из корня проекта |
|---|---|
| Состояние стенда | `bash scripts/manage.sh status` |
| Поды | `bash scripts/manage.sh kubectl -n sentiment get pods -o wide` |
| CPU и память | `bash scripts/manage.sh kubectl -n sentiment top pods` |
| Наблюдение HPA | `bash scripts/manage.sh kubectl -n sentiment get hpa -w` |
| Любая команда Minikube | `bash scripts/manage.sh minikube status` |
| Helm releases | `bash scripts/manage.sh helm list -n monitoring` |
| Сбор журналов | `bash scripts/manage.sh collect` |

### Сборка и повторное развертывание

```bash
bash scripts/manage.sh deploy
bash scripts/manage.sh collect
```

Это полное развертывание с пересборкой образа и обновлением Helm release. Для обычной проверки работающего стенда достаточно `status`; повторный `deploy` не нужен.

Отдельная пересборка и применение манифестов:

```bash
docker build -t sentiment-api:1.0.1 .
bash scripts/manage.sh minikube image load sentiment-api:1.0.1
bash scripts/manage.sh kubectl apply -f "$PWD/k8s/app.yaml"
```

Для чистой установки, когда профиля еще нет, либо если одинаковый профиль найден у нескольких пользователей, укажите существующую Linux-учетную запись явно:

```bash
CLUSTER_USER=student bash scripts/manage.sh deploy
```

`student` — пример: замените на свое имя. Аккаунт должен существовать и иметь доступ к Docker. Создавать новый профиль в `/root` или переносить уже работающий профиль не требуется. Minikube с Docker-драйвером запускается учетной записью владельца; для туннеля в root-сеансе права на маршрут используются напрямую. Это сохраняет существующий кластер и позволяет работать из root без паролей переключения.

## Размер контейнера

Образ 1.0.1: **94 334 976 байт (94,33 MB)** распакованных слоев. Файл `evidence/docker-layer-size-1.0.1.log`. Это меньше 150 000 000 байт. В Docker 29 containerd store `.Size` учитывает сжатое и распакованное хранение вместе; это другой показатель: https://docs.docker.com/engine/storage/containerd/ . Для требования использована сумма слоев из `docker history --human=false`. Скрипт проверяет тот же показатель. Не сравнивайте размер JAR с размером образа.

Тег образа 1.0.1 включает `jdk.management`, устранивший предупреждение о GC metrics. Maven-версия JAR остается 1.0.0. Тесты Maven выполнялись в первой сборке; при пересборке измененного runtime слой тестов был кеширован.

## Доступ через Ingress

В Ubuntu VM:

```bash
curl -i -H 'Host: sentiment.local' 'http://192.168.49.2/api/sentiment?text=hello'
```

Ingress маршрутизирует `/api` на Service sentiment:80. Для нового профиля IP может отличаться: проверьте `bash scripts/manage.sh minikube ip`. Журнал `evidence/ingress-balance.log` содержит 15 ответов трех Pod (7/5/3); равномерность на большой выборке не измерялась.

## Доступ через LoadBalancer

В отдельном окне:

```bash
bash scripts/manage.sh tunnel
```

Оставьте окно открытым. В другом окне VM:

```bash
bash scripts/manage.sh kubectl -n sentiment get svc sentiment
curl -i 'http://10.107.117.240/api/sentiment?text=hello'
```

Адрес относится к фактическому профилю; при новом создании возьмите EXTERNAL-IP из вывода. Доступ проверен с VM, не напрямую с Windows. Без работающего tunnel ожидается pending. Если найден другой tunnel, сначала определите его процесс и штатно остановите конкретный экземпляр. Не запускайте несколько туннелей.

## Grafana и Prometheus

В отдельных окнах VM:

```bash
bash scripts/manage.sh grafana 100.127.255.81
bash scripts/manage.sh prometheus 100.127.255.81
```

Откройте Grafana на http://100.127.255.81:3000 и Prometheus на http://100.127.255.81:9090/targets . У нового стенда адрес VM и имена Service могут отличаться; проверьте `bash scripts/manage.sh kubectl -n monitoring get svc`. Вход Grafana — admin, пароль берется из Secret локально и не включается в комплект. Если не указать IP после `grafana` или `prometheus`, порт слушает только 127.0.0.1. Окна с port-forward нужно оставить открытыми.

Дашборд `Sentiment API Overview` импортируется ConfigMap и sidecar. ServiceMonitor выбирает внутренний Service на 8081. В Prometheus подтверждены три UP по `/actuator/prometheus`. У системных scheduler, controller-manager и etcd обнаружен connection refused; их мониторинг не настроен полностью. Alertmanager отключен, retention метрик 6 часов, постоянные тома для сохранения истории не настроены. Port-forward требует работающего процесса; после его остановки веб-доступ пропадает.

## Нагрузочная проверка HPA

```bash
bash scripts/manage.sh load
bash scripts/manage.sh kubectl -n sentiment get hpa -w
```

Fortio: 64 соединения, 300 секунд, QPS без ограничения. Наблюдайте до и после нагрузки. Старый Job удаляется автоматически через TTL; для немедленного повтора сначала сохраните его logs, затем удалите именно `job/sentiment-load` и примените YAML заново. Ctrl+C останавливает наблюдение, а не Deployment. HPA: CPU 60% от requests 100m, 3–6 реплик, стабилизация scaleDown 120 секунд. Реально зафиксирован цикл 3 → 6 → 3. Точные задержки реакции и предел производительности статистически не измерялись.

На снимке Grafana пик около 9 тыс. RPS, CPU около 2,4 cores, p95 около 0,97–1,09 мс. Это чтение изображения одного опыта, не гарантия. p95 — серверная метрика. `No data` у 5xx не доказывает отсутствие ошибок.

## Материалы и публикация

Для сдачи используйте последнюю сокращенную версию `SentimentOps_Report_10pages.docx`: 10 страниц вместе с титульным листом, обзором пяти статей и источниками. Предыдущие длинные документы и отдельное аналитическое приложение не заменяют эту версию. Презентация содержит 14 слайдов. `evidence/screenshots/` — реальные снимки. Исторические исходные документы и первый неуспешный журнал находятся в `history/`; их нельзя выдавать за актуальный результат.

В комплекте подготовлена локальная история Git. Публичный удаленный репозиторий еще не создан и ссылка не предоставлена. Перед отправкой ментору опубликуйте проект в выбранном Git-сервисе и добавьте реальный URL в этот README и материалы. Архив не содержит kubeconfig, паролей и ключей.

## Источники

Пять статей и официальная документация перечислены в сокращенном отчете; дата обращения 16 ноября 2026 года. Числа исследований не выдаются за локальные измерения.
