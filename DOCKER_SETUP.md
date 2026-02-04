# Docker Compose Setup

Полное руководство по запуску CallFlowEngine в Docker.

## 🐳 Быстрый старт

### Development режим

```bash
# 1. Создайте .env файл
cp .env.docker .env

# 2. Запустите все сервисы
docker-compose up -d

# 3. Просмотр логов
docker-compose logs -f app

# 4. Проверка здоровья
curl http://localhost:4000/health
```

Приложение будет доступно на `http://localhost:4000`

### Production режим

```bash
# 1. Создайте production .env
cp .env.docker .env
# Отредактируйте .env с production значениями

# 2. Сгенерируйте SECRET_KEY_BASE
docker run --rm elixir:1.14-alpine sh -c "mix local.hex --force && mix phx.gen.secret"
# Добавьте в .env

# 3. Запустите production stack
docker-compose -f docker-compose.prod.yml up -d

# 4. Проверка
curl http://localhost:4000/health
```

## 📁 Структура Docker файлов

```
call_flow_engine/
├── Dockerfile              # Production image (multi-stage)
├── Dockerfile.dev          # Development image (hot reload)
├── docker-compose.yml      # Development stack
├── docker-compose.prod.yml # Production stack
├── .dockerignore           # Игнорируемые файлы
├── .env.docker             # Шаблон переменных
└── nginx.conf              # Nginx для production
```

## 🛠️ Dockerfile объяснение

### Dockerfile (Production)

**Multi-stage build** для минимального образа:

1. **Builder stage** (elixir:1.14-alpine)
   - Установка зависимостей
   - Компиляция приложения
   - Создание release

2. **Runtime stage** (alpine:3.18)
   - Минимальный образ (~50MB)
   - Только runtime зависимости
   - Non-root пользователь (app)
   - Health check встроен

### Dockerfile.dev (Development)

- Hot reload (код монтируется как volume)
- Все dev зависимости
- inotify-tools для file watching
- PostgreSQL client для отладки

## 🚀 Команды Docker Compose

### Development

```bash
# Запуск
docker-compose up -d

# Остановка
docker-compose down

# Пересборка после изменения зависимостей
docker-compose up -d --build

# Просмотр логов
docker-compose logs -f app
docker-compose logs -f postgres

# Выполнение команд внутри контейнера
docker-compose exec app mix test
docker-compose exec app mix ecto.migrate
docker-compose exec app iex -S mix

# Подключение к PostgreSQL
docker-compose exec postgres psql -U postgres -d call_flow_engine_dev

# Полная очистка (включая volumes)
docker-compose down -v
```

### Production

```bash
# Запуск
docker-compose -f docker-compose.prod.yml up -d

# Просмотр состояния
docker-compose -f docker-compose.prod.yml ps

# Логи
docker-compose -f docker-compose.prod.yml logs -f

# Рестарт приложения
docker-compose -f docker-compose.prod.yml restart app

# Обновление образа
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d

# Остановка
docker-compose -f docker-compose.prod.yml down
```

## ⚙️ Переменные окружения

### Обязательные для Production

Создайте `.env` файл:

```env
# Database
POSTGRES_PASSWORD=your_strong_password
DATABASE_URL=ecto://postgres:your_strong_password@postgres:5432/call_flow_engine_prod

# ARI
ARI_URL=ws://your-asterisk:8088/ari/events
ARI_USER=your_ari_user
ARI_PASSWORD=your_ari_password

# Bitrix24
BITRIX_WEBHOOK_URL=https://your-bitrix.bitrix24.com/rest/1/xyz/

# Phoenix
SECRET_KEY_BASE=generate_with_mix_phx_gen_secret_64_chars_minimum
PHX_HOST=your-domain.com
```

### Опциональные

```env
# Logging
LOG_LEVEL=info  # debug | info | warning | error

# Database
POSTGRES_USER=postgres
POSTGRES_DB=call_flow_engine_prod

# ARI
ARI_APP_NAME=callflow_elixir

# Performance
POOL_SIZE=10
```

## 🔄 Hot Reload в Development

Development режим поддерживает hot reload:

```bash
# Код монтируется как volume
docker-compose up -d

# Изменяйте файлы в lib/
# Phoenix автоматически перезагрузит код
```

**Исключения** (требуют пересборки):
- Изменения в `mix.exs` (зависимости)
- Изменения в `config/*.exs`

Пересоберите после таких изменений:
```bash
docker-compose up -d --build
```

## 📊 Мониторинг

### Health Checks

Встроенные health checks в docker-compose:

```bash
# Проверка состояния
docker-compose ps

# Должно показать "healthy" для app и postgres
```

### Логи

```bash
# Все сервисы
docker-compose logs -f

# Только приложение
docker-compose logs -f app

# Последние 100 строк
docker-compose logs --tail=100 app

# С временными метками
docker-compose logs -f -t app
```

### Метрики контейнеров

```bash
# Использование ресурсов
docker stats

# Детали контейнера
docker inspect call_flow_engine_app
```

## 🗄️ Database Management

### Миграции

```bash
# Создать БД
docker-compose exec app mix ecto.create

# Запустить миграции
docker-compose exec app mix ecto.migrate

# Откат миграции
docker-compose exec app mix ecto.rollback

# Пересоздать БД (ОПАСНО!)
docker-compose exec app mix ecto.reset
```

### Backup и Restore

```bash
# Backup
docker-compose exec postgres pg_dump -U postgres call_flow_engine_dev > backup.sql

# Restore
docker-compose exec -T postgres psql -U postgres call_flow_engine_dev < backup.sql
```

## 🧪 Тестирование в Docker

### Запуск тестов

```bash
# В running контейнере
docker-compose exec app mix test

# С покрытием
docker-compose exec app mix test --cover

# Конкретный тест
docker-compose exec app mix test test/call_flow_engine/events/event_processor_test.exs
```

### Отладка

```bash
# IEx shell
docker-compose exec app iex -S mix

# В IEx можно вызывать:
iex> CallFlowEngine.Events.EventProcessor.get_stats()
iex> CallFlowEngine.Repo.all(CallFlowEngine.Calls.Call)
```

## 🌐 Nginx Production Setup

### С SSL (Let's Encrypt)

1. **Получите сертификаты:**

```bash
# Используйте certbot
docker run -it --rm \
  -v ./ssl:/etc/letsencrypt \
  certbot/certbot certonly --standalone \
  -d your-domain.com \
  --email your@email.com \
  --agree-tos
```

2. **Обновите nginx.conf:**

Раскомментируйте HTTPS секцию и укажите пути к сертификатам.

3. **Перезапустите:**

```bash
docker-compose -f docker-compose.prod.yml restart nginx
```

### Rate Limiting

В `nginx.conf` настроен rate limiting:
- API endpoints: 10 req/s с burst 20
- Health check: без лимитов

Настройте под свои нужды.

## 🔒 Безопасность

### Production Checklist

- [ ] Измените все пароли в `.env`
- [ ] Сгенерируйте новый `SECRET_KEY_BASE`
- [ ] Используйте SSL/TLS (HTTPS)
- [ ] Настройте firewall (только 80, 443)
- [ ] Ограничьте доступ к PostgreSQL (убрать ports из docker-compose)
- [ ] Настройте backup базы данных
- [ ] Включите логирование в централизованную систему
- [ ] Настройте мониторинг (Prometheus/Grafana)

### Не экспонировать порты в production

В `docker-compose.prod.yml` убрать:
```yaml
postgres:
  ports:
    - "5432:5432"  # Удалить эту строку
```

PostgreSQL будет доступен только внутри Docker сети.

## 🐛 Troubleshooting

### Контейнер app не стартует

```bash
# Просмотрите логи
docker-compose logs app

# Проверьте что PostgreSQL здоров
docker-compose ps postgres

# Попробуйте пересоздать
docker-compose down
docker-compose up -d --build
```

### Ошибка "connection refused" к PostgreSQL

**Причина:** App стартует быстрее чем PostgreSQL готов.

**Решение:** В docker-compose.yml уже настроен `depends_on` с `condition: service_healthy`. Если проблема сохраняется:

```bash
# Перезапустите app после старта postgres
docker-compose restart app
```

### Нет места на диске

```bash
# Очистите неиспользуемые образы
docker system prune -a

# Удалите старые volumes (ОСТОРОЖНО!)
docker volume prune
```

### Медленная компиляция

**В development:**
- Используйте volumes для `deps/` и `_build/`
- Уже настроено в `docker-compose.yml`

### Hot reload не работает

```bash
# Проверьте что код монтируется
docker-compose exec app ls -la /app

# Перезапустите
docker-compose restart app
```

## 📈 Performance Tuning

### PostgreSQL

Добавьте в `docker-compose.yml`:

```yaml
postgres:
  command: postgres -c shared_buffers=256MB -c max_connections=200
```

### Elixir App

Переменные окружения:

```env
POOL_SIZE=10          # Размер connection pool
ERL_MAX_PORTS=4096    # Максимум портов Erlang
```

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Docker Build

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build Docker image
        run: docker build -t callflowengine:latest .
      
      - name: Run tests in Docker
        run: |
          docker-compose up -d
          docker-compose exec -T app mix test
```

## 📦 Размер образов

- **Production image:** ~50MB (Alpine + release)
- **Development image:** ~200MB (с dev tools)
- **PostgreSQL:** ~230MB (официальный Alpine)

## 🎯 Best Practices

1. **Используйте .env файлы** - никогда не коммитьте секреты
2. **Multi-stage builds** - минимизируют production образ
3. **Health checks** - автоматический restart при проблемах
4. **Named volumes** - персистентность данных
5. **Networks** - изоляция сервисов
6. **Non-root user** - безопасность
7. **Logging** - структурированные логи для анализа

## 🆘 Получение помощи

Проблемы с Docker?

1. Проверьте логи: `docker-compose logs -f`
2. Проверьте здоровье: `docker-compose ps`
3. Проверьте сеть: `docker network inspect call_flow_network`
4. Откройте Issue в репозитории

---

**Готово!** Ваш CallFlowEngine работает в Docker 🐳
