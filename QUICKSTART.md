# Quick Start Guide

Самый быстрый способ запустить CallFlowEngine.

## ⚡ 30-секундный старт

```bash
# 1. Перейдите в директорию
cd call_flow_engine

# 2. Запустите deployment скрипт
chmod +x deploy.sh
./deploy.sh

# 3. Готово! Проверьте здоровье
curl http://localhost:4100/health
```

**Windows:**
```powershell
cd call_flow_engine
.\deploy-windows.ps1
curl http://localhost:4100/health
```

## 🎯 Что произойдет

Deployment скрипт автоматически:

1. ✅ Проверит Docker установлен и запущен
2. ✅ Предложит настроить порты (нестандартные по умолчанию)
3. ✅ Сгенерирует конфигурацию (.env)
4. ✅ Создаст Docker Compose override
5. ✅ Соберет Docker образы
6. ✅ Запустит PostgreSQL + Elixir app
7. ✅ Дождется health check
8. ✅ Создаст первый backup

**Время выполнения:** ~2-3 минуты (первый раз)

## 🔌 Порты по умолчанию

| Сервис | Порт | URL |
|--------|------|-----|
| Phoenix App | 4100 | http://localhost:4100 |
| PostgreSQL | 5433 | localhost:5433 |
| Nginx | 8100 | http://localhost:8100 |

**Можно изменить** при установке или в `.env.ports`

## 🧪 Быстрый тест

### 1. Проверка здоровья
```bash
curl http://localhost:4100/health
```

Ответ:
```json
{
  "status": "ok",
  "db": "ok",
  "ari_connection": "connected"
}
```

### 2. Статистика
```bash
curl http://localhost:4100/api/stats
```

### 3. Создание тестового звонка

**Начало звонка:**
```bash
curl -X POST http://localhost:4100/api/test/events \
  -H "Content-Type: application/json" \
  -d '{
    "call_id": "demo-001",
    "event_type": "stasis_start",
    "payload": {
      "caller": "+1234567890",
      "callee": "9091",
      "direction": "inbound"
    }
  }'
```

**Ответ на звонок:**
```bash
curl -X POST http://localhost:4100/api/test/events \
  -H "Content-Type: application/json" \
  -d '{
    "call_id": "demo-001",
    "event_type": "state_change",
    "payload": {"state": "Up"}
  }'
```

**Завершение звонка:**
```bash
curl -X POST http://localhost:4100/api/test/events \
  -H "Content-Type: application/json" \
  -d '{
    "call_id": "demo-001",
    "event_type": "stasis_end",
    "payload": {}
  }'
```

### 4. Просмотр созданного звонка
```bash
curl http://localhost:4100/api/calls
```

Ответ:
```json
[
  {
    "call_id": "demo-001",
    "direction": "inbound",
    "caller_number": "+1234567890",
    "callee_number": "9091",
    "status": "finished",
    "started_at": "2026-02-04T19:00:00Z",
    "answered_at": "2026-02-04T19:00:05Z",
    "ended_at": "2026-02-04T19:02:00Z"
  }
]
```

## 🔄 Обновление

```bash
# Обновить до последней версии
./deploy.sh --update

# Проверить статус
./deploy.sh --status

# Откатить при проблемах
./deploy.sh --rollback
```

## 🛠️ Управление

### Просмотр логов
```bash
docker-compose -p callflow logs -f app
```

### Остановка
```bash
docker-compose -p callflow down
```

### Запуск тестов
```bash
docker-compose -p callflow exec app mix test
```

### IEx Shell
```bash
docker-compose -p callflow exec app iex -S mix
```

## 📊 Мониторинг

### Метрики контейнеров
```bash
docker stats
```

### Проверка здоровья сервисов
```bash
docker-compose -p callflow ps
```

## 🆘 Проблемы?

### Порт занят
```bash
# Проверить что занимает порт
lsof -i :4100

# Изменить порт
nano .env.ports  # Измените APP_PORT
./deploy.sh      # Перезапустите
```

### Docker не запущен
```bash
# Linux
sudo systemctl start docker

# macOS - откройте Docker Desktop
open /Applications/Docker.app
```

### Health check fails
```bash
# Проверьте логи
docker-compose -p callflow logs app

# Проверьте БД
docker-compose -p callflow exec postgres psql -U postgres -l
```

## 📖 Полная документация

- **README.md** - Основная документация (600+ строк)
- **ARCHITECTURE.md** - Архитектура системы
- **DOCKER_SETUP.md** - Docker guide
- **DEPLOYMENT.md** - Production deployment
- **IMPROVEMENTS.md** - v0.2.0 improvements

## 🎓 Обучение

### Запустить и изучить
```bash
# 1. Запустите проект
./deploy.sh

# 2. Откройте IEx shell
docker-compose -p callflow exec app iex -S mix

# 3. Поиграйте с API
iex> CallFlowEngine.Events.EventProcessor.get_stats()
iex> CallFlowEngine.Calls.CallService.list_calls()
iex> CallFlowEngine.Calls.CallRegistry.clear()
```

### Изучить код
```bash
# Архитектура
cat ARCHITECTURE.md

# Code review findings
cat CODE_REVIEW.md

# Improvements
cat IMPROVEMENTS.md
```

---

**Время на быстрый старт:** ~3 минуты  
**Время на полное изучение:** ~30 минут  
**Ready for Production!** 🚀
