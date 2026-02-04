# Deployment Guide

Полное руководство по развертыванию CallFlowEngine на production/staging серверах.

## 📋 Содержание

- [Быстрый старт](#быстрый-старт)
- [Системные требования](#системные-требования)
- [Deployment скрипты](#deployment-скрипты)
- [Конфигурация портов](#конфигурация-портов)
- [Обновление системы](#обновление-системы)
- [Rollback](#rollback)
- [Мониторинг](#мониторинг)
- [Troubleshooting](#troubleshooting)

## 🚀 Быстрый старт

### Linux/macOS

```bash
# 1. Склонируйте репозиторий
git clone <repository-url>
cd call_flow_engine

# 2. Сделайте скрипт исполняемым
chmod +x deploy.sh

# 3. Запустите deployment
./deploy.sh
```

### Windows

```powershell
# 1. Склонируйте репозиторий
git clone <repository-url>
cd call_flow_engine

# 2. Запустите deployment
.\deploy-windows.ps1
```

## 💻 Системные требования

### Минимальные требования

- **OS:** Linux (Ubuntu 20.04+), macOS 11+, Windows 10+ с WSL2
- **CPU:** 2 cores
- **RAM:** 4 GB
- **Disk:** 20 GB свободного места
- **Docker:** 20.10+
- **Docker Compose:** 1.29+

### Рекомендуемые для production

- **CPU:** 4+ cores
- **RAM:** 8+ GB
- **Disk:** 50+ GB SSD
- **Docker:** latest stable
- **Docker Compose:** 2.x

## 🛠️ Deployment скрипты

### deploy.sh (Linux/macOS)

Основной deployment скрипт с полным функционалом:

```bash
# Начальная установка
./deploy.sh

# Обновление
./deploy.sh --update

# Откат к предыдущей версии
./deploy.sh --rollback

# Проверка статуса
./deploy.sh --status

# Справка
./deploy.sh --help
```

### deploy-windows.ps1 (Windows)

PowerShell версия для Windows:

```powershell
# Начальная установка
.\deploy-windows.ps1

# Обновление
.\deploy-windows.ps1 -Update

# Проверка статуса
.\deploy-windows.ps1 -Status

# Справка
.\deploy-windows.ps1 -Help
```

## 🔌 Конфигурация портов

При первом запуске скрипт предложит настроить порты. По умолчанию используются **нестандартные порты** для избежания конфликтов:

| Сервис | Порт по умолчанию | Стандартный порт | Назначение |
|--------|-------------------|------------------|------------|
| Phoenix App | **4100** | 4000 | Основное приложение |
| PostgreSQL | **5433** | 5432 | База данных |
| Nginx | **8100** | 80 | Reverse proxy (опционально) |

### Изменение портов

Порты сохраняются в файле `.env.ports`:

```bash
# Port configuration for CallFlowEngine
APP_PORT=4100
POSTGRES_PORT=5433
NGINX_PORT=8100
```

Для изменения портов:

1. Остановите сервисы: `docker-compose -p callflow down`
2. Отредактируйте `.env.ports`
3. Пересоздайте override: удалите `docker-compose.override.yml`
4. Запустите заново: `./deploy.sh`

### Проверка занятости портов

**Linux/macOS:**
```bash
# Проверить один порт
lsof -i :4100

# Проверить все используемые порты
netstat -tuln | grep LISTEN
```

**Windows:**
```powershell
# Проверить порт
Get-NetTCPConnection -LocalPort 4100

# Все занятые порты
netstat -ano | findstr LISTENING
```

## 🔄 Обновление системы

### Автоматическое обновление

```bash
./deploy.sh --update
```

Скрипт выполнит:

1. ✅ **Backup** - создаст резервную копию БД и конфигурации
2. ✅ **Git pull** - получит последние изменения (если .git существует)
3. ✅ **Smart rebuild** - пересоберёт только при изменении Dockerfile/dependencies
4. ✅ **Zero-downtime restart** - перезапустит сервисы без простоя
5. ✅ **Database migrations** - применит миграции БД
6. ✅ **Health check** - проверит работоспособность
7. ✅ **Auto-rollback** - откатит при ошибках

### Что триггерит rebuild?

- Изменения в `Dockerfile`, `Dockerfile.dev`
- Изменения в `mix.exs`, `mix.lock` (зависимости)
- Изменения в `lib/` (код приложения)

### Что триггерит restart?

- Изменения в `config/` (конфигурация)
- Изменения в `docker-compose*.yml`
- Rebuild приложения

### Ручное обновление

Если нужен полный контроль:

```bash
# 1. Создать backup
docker exec callflow_postgres pg_dump -U postgres call_flow_engine_dev > backup.sql

# 2. Pull изменений
git pull origin main

# 3. Rebuild
docker-compose -p callflow build --no-cache

# 4. Restart
docker-compose -p callflow up -d

# 5. Migrations
docker-compose -p callflow exec app mix ecto.migrate
```

## ⏪ Rollback

### Автоматический откат

```bash
./deploy.sh --rollback
```

Восстановит последний backup (конфигурацию + БД).

### Ручной откат к конкретной версии

```bash
# Просмотреть backups
ls -lh backups/

# Восстановить конкретный backup
tar -xzf backups/backup_20260204_193000.tar.gz

# Restart сервисов
docker-compose -p callflow down
docker-compose -p callflow up -d
```

### Откат БД

```bash
# Восстановить дамп БД
docker exec -i callflow_postgres psql -U postgres call_flow_engine_dev < backups/db_20260204_193000.sql
```

## 📊 Мониторинг

### Проверка статуса

```bash
./deploy.sh --status
```

Показывает:
- Статус контейнеров
- Health check результат
- Disk usage
- Последние логи

### Просмотр логов

```bash
# Все сервисы
docker-compose -p callflow logs -f

# Только app
docker-compose -p callflow logs -f app

# Последние 100 строк
docker-compose -p callflow logs --tail=100 app

# С временными метками
docker-compose -p callflow logs -f -t
```

### Метрики контейнеров

```bash
# Использование CPU/RAM
docker stats

# Детальная информация
docker inspect callflow_app
```

### Health checks

```bash
# Через API
curl http://localhost:4100/health | jq .

# Response:
{
  "status": "ok",
  "db": "ok",
  "ari_connection": "connected",
  "timestamp": "2026-02-04T19:30:00Z"
}
```

## 🔥 Горячие команды

```bash
# Restart приложения
docker-compose -p callflow restart app

# Rebuild без cache
docker-compose -p callflow build --no-cache

# Просмотр переменных окружения
docker-compose -p callflow exec app env

# Подключение к БД
docker-compose -p callflow exec postgres psql -U postgres call_flow_engine_dev

# IEx shell
docker-compose -p callflow exec app iex -S mix

# Запуск тестов
docker-compose -p callflow exec app mix test

# Миграции
docker-compose -p callflow exec app mix ecto.migrate

# Rollback последней миграции
docker-compose -p callflow exec app mix ecto.rollback

# Очистка старых образов
docker system prune -a
```

## 🐛 Troubleshooting

### Проблема: Порт уже занят

**Симптом:**
```
Error: bind: address already in use
```

**Решение:**
1. Найдите процесс: `lsof -i :4100` (или `netstat` на Windows)
2. Остановите процесс или измените порт в `.env.ports`
3. Пересоздайте deployment

### Проблема: Deploy скрипт не запускается

**Linux/macOS:**
```bash
# Сделать исполняемым
chmod +x deploy.sh

# Проверить права
ls -l deploy.sh
```

**Windows:**
```powershell
# Разрешить выполнение PowerShell скриптов
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Проблема: Docker not running

**Решение:**
```bash
# Linux
sudo systemctl start docker

# macOS
open /Applications/Docker.app

# Windows
# Запустите Docker Desktop
```

### Проблема: Нет места на диске

```bash
# Очистить неиспользуемые образы
docker system prune -a

# Очистить volumes (ОСТОРОЖНО! Удалит данные)
docker volume prune

# Проверить место
docker system df
```

### Проблема: Health check fails

```bash
# Проверьте логи
docker-compose -p callflow logs app

# Проверьте что БД доступна
docker-compose -p callflow exec app mix ecto.migrate

# Попробуйте restart
docker-compose -p callflow restart app
```

### Проблема: Update fails

```bash
# Откатитесь к предыдущей версии
./deploy.sh --rollback

# Проверьте логи
cat deploy.log

# Попробуйте manual update
docker-compose -p callflow down
docker-compose -p callflow build --no-cache
docker-compose -p callflow up -d
```

## 📈 Production Best Practices

### 1. Используйте отдельный сервер для production

Не смешивайте dev и prod на одном сервере.

### 2. Настройте firewall

```bash
# Ubuntu/Debian
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 4100/tcp  # App (если нужен внешний доступ)
sudo ufw enable
```

### 3. Настройте SSL/TLS

Используйте Nginx с Let's Encrypt:

```bash
# Установите certbot
sudo apt install certbot

# Получите сертификат
sudo certbot certonly --standalone -d your-domain.com

# Обновите nginx.conf с путями к сертификатам
```

### 4. Настройте backup schedule

```bash
# Добавьте в crontab
crontab -e

# Backup каждую ночь в 2:00
0 2 * * * cd /path/to/call_flow_engine && ./deploy.sh --status >> backup.log 2>&1
```

### 5. Мониторинг

Используйте внешние системы мониторинга:
- Prometheus + Grafana
- Datadog
- New Relic
- Sentry для ошибок

### 6. Логирование

Настройте централизованное логирование:
- ELK Stack (Elasticsearch, Logstash, Kibana)
- Loki + Grafana
- CloudWatch (AWS)

## 🔐 Безопасность

### Checklist перед production

- [ ] Измените все пароли в `.env`
- [ ] Сгенерируйте новый `SECRET_KEY_BASE`
- [ ] Используйте SSL/TLS (HTTPS)
- [ ] Настройте firewall
- [ ] Ограничьте доступ к PostgreSQL порту
- [ ] Регулярные backups
- [ ] Мониторинг и алерты
- [ ] Обновления безопасности Docker/OS
- [ ] Rate limiting на Nginx
- [ ] WAF (Web Application Firewall)

## 📞 Поддержка

При возникновении проблем:

1. Проверьте логи: `cat deploy.log`
2. Проверьте статус: `./deploy.sh --status`
3. Проверьте документацию: `README.md`, `DOCKER_SETUP.md`
4. Откройте Issue на GitHub

---

**Happy Deploying!** 🚀
