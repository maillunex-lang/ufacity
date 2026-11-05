---
name: vps-one-box
description: >
  Выкладка API этой игры на один свой VPS: nginx, HTTPS, Postgres, бэкап.
  Use when deploying, configuring nginx, certificates, firewall, backups, or a health check.
---

# Один VPS

Один хост: nginx снаружи, API на localhost, Postgres на localhost.
Наружу только 22, 80 и 443. SSH по ключу.
HTTPS через обычный сертификат на домен. Секрет сертификата не в git.

Выкладка: git pull на сервере или один docker compose из трёх сервисов: nginx, API, Postgres.
Не кластер и не Kubernetes.

Бэкап Postgres каждый день. Копия не только на том же диске.
Лог API на диск с ротацией.
Миграции базы до перезапуска процесса, не руками в проде.
После деплоя проверить одну ручку здоровья, без секретов в ответе.

Выход: схема процессов и чеклист первого деплоя.
