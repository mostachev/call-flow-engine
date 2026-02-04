# Инструкции по установке и запуску

## Важно! Установка Elixir

Данный проект создан **без запуска `mix phx.new`**, так как Elixir не установлен в системе. Все файлы созданы вручную согласно стандартной структуре Phoenix проекта.

## Шаг 1: Установка Elixir и Phoenix

### Windows

```powershell
# Установите через Chocolatey
choco install elixir

# Или скачайте installer с официального сайта
# https://elixir-lang.org/install.html#windows

# После установки Elixir, установите Hex и Phoenix
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new --force
```

### Linux (Ubuntu/Debian)

```bash
# Добавьте репозиторий Erlang Solutions
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt-get update

# Установите Erlang и Elixir
sudo apt-get install esl-erlang elixir

# Установите Hex и Phoenix
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new --force
```

### macOS

```bash
# Установите через Homebrew
brew install elixir

# Установите Hex и Phoenix
mix local.hex --force
mix local.rebar --force
mix archive.install hex phx_new --force
```

## Шаг 2: Проверка установки

```bash
elixir --version
# Должно показать: Elixir 1.14 (compiled with Erlang/OTP 25)

mix --version
# Должно показать версию Mix
```

## Шаг 3: Установка зависимостей проекта

```bash
cd call_flow_engine

# Установите зависимости
mix deps.get

# Скомпилируйте проект
mix compile
```

## Шаг 4: Настройка базы данных

### Вариант А: Через Docker Compose (рекомендуется)

```bash
# Запустите PostgreSQL
docker-compose up -d

# Проверьте что контейнер запущен
docker ps

# Создайте и мигрируйте БД
mix ecto.create
mix ecto.migrate
```

### Вариант Б: Существующий PostgreSQL

Отредактируйте `config/dev.exs`:

```elixir
config :call_flow_engine, CallFlowEngine.Repo,
  username: "ваш_пользователь",
  password: "ваш_пароль",
  hostname: "localhost",
  database: "call_flow_engine_dev",
  pool_size: 10
```

Затем:

```bash
mix ecto.create
mix ecto.migrate
```

## Шаг 5: Конфигурация

Создайте файл `.env`:

```bash
cp .env.example .env
```

Отредактируйте `.env` согласно вашим настройкам:

```env
DATABASE_URL=ecto://postgres:postgres@localhost/call_flow_engine_dev
ARI_URL=ws://localhost:8088/ari/events
ARI_USER=asterisk
ARI_PASSWORD=asterisk
ARI_APP_NAME=callflow_elixir
BITRIX_WEBHOOK_URL=https://your-bitrix.bitrix24.com/rest/1/xyz/
LOG_LEVEL=info
```

**Важно:**
- `ARI_URL` - если Asterisk не настроен, можно оставить как есть (ARI Connection будет в mock режиме)
- `BITRIX_WEBHOOK_URL` - если Bitrix24 не настроен, укажите mock URL

## Шаг 6: Запуск сервера

```bash
mix phx.server
```

Сервер запустится на `http://localhost:4000`

## Шаг 7: Проверка работоспособности

### Через curl

```bash
# Health check
curl http://localhost:4000/health

# Статистика
curl http://localhost:4000/api/stats

# Тестовое событие (полный жизненный цикл звонка)
# 1. Начало звонка
curl -X POST http://localhost:4000/api/test/events \
  -H "Content-Type: application/json" \
  -d '{
    "call_id": "demo-call-001",
    "event_type": "stasis_start",
    "payload": {
      "caller": "+1234567890",
      "callee": "9091",
      "direction": "inbound"
    }
  }'

# 2. Ответ на звонок
curl -X POST http://localhost:4000/api/test/events \
  -H "Content-Type: application/json" \
  -d '{
    "call_id": "demo-call-001",
    "event_type": "state_change",
    "payload": {
      "state": "Up"
    }
  }'

# 3. Завершение звонка
curl -X POST http://localhost:4000/api/test/events \
  -H "Content-Type: application/json" \
  -d '{
    "call_id": "demo-call-001",
    "event_type": "stasis_end",
    "payload": {}
  }'

# Просмотр созданного звонка
curl http://localhost:4000/api/calls
```

### Через браузер

Откройте в браузере:
- `http://localhost:4000/health` - статус сервиса
- `http://localhost:4000/api/stats` - статистика
- `http://localhost:4000/api/calls` - список звонков

## Шаг 8: Запуск тестов

```bash
# Создайте тестовую БД
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate

# Запустите тесты
mix test

# С покрытием
mix test --cover
```

## Структура проекта

```
call_flow_engine/
├── config/                 # Конфигурация
│   ├── config.exs         # Общая конфигурация
│   ├── dev.exs            # Development
│   ├── test.exs           # Test
│   ├── prod.exs           # Production
│   └── runtime.exs        # Runtime (ENV vars)
├── lib/
│   ├── call_flow_engine/
│   │   ├── application.ex      # OTP Application
│   │   ├── repo.ex            # Ecto Repo
│   │   ├── ari/
│   │   │   ├── connection.ex   # WebSocket клиент
│   │   │   └── event_router.ex # Роутер событий
│   │   ├── calls/
│   │   │   ├── call.ex        # Schema
│   │   │   └── call_service.ex # Бизнес-логика
│   │   ├── events/
│   │   │   ├── call_event.ex       # Schema
│   │   │   ├── call_event_payload.ex # Payload struct
│   │   │   └── event_processor.ex  # GenServer
│   │   └── integrations/
│   │       └── bitrix_client.ex   # HTTP клиент
│   └── call_flow_engine_web/
│       ├── endpoint.ex        # Phoenix Endpoint
│       ├── router.ex          # Роуты
│       └── controllers/       # REST контроллеры
├── priv/
│   └── repo/
│       └── migrations/        # DB миграции
├── test/                      # Тесты
├── mix.exs                    # Mix project
├── docker-compose.yml         # PostgreSQL
├── .env.example               # Пример переменных
└── README.md                  # Документация
```

## Troubleshooting

### Проблема: `mix: command not found`

**Решение:** Elixir не установлен или не добавлен в PATH. Переустановите Elixir.

### Проблема: `(Mix) Could not compile dependency`

**Решение:**
```bash
mix deps.clean --all
mix deps.get
mix compile
```

### Проблема: `(DBConnection.ConnectionError) connection not available`

**Решение:**
```bash
# Проверьте что PostgreSQL запущен
docker-compose ps

# Перезапустите PostgreSQL
docker-compose restart postgres
```

### Проблема: Порт 4000 уже занят

**Решение:**
Отредактируйте `config/dev.exs`:
```elixir
config :call_flow_engine, CallFlowEngineWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001],  # Измените порт
```

## Следующие шаги

1. **Подключение к реальному Asterisk:**
   - Настройте `ari.conf` в Asterisk
   - Добавьте Stasis приложение в `extensions.conf`
   - Обновите `ARI_URL`, `ARI_USER`, `ARI_PASSWORD` в `.env`

2. **Интеграция с Bitrix24:**
   - Создайте входящий webhook в Bitrix24
   - Укажите полученный URL в `BITRIX_WEBHOOK_URL`

3. **Production deployment:**
   - Настройте `config/runtime.exs` для production
   - Сгенерируйте `SECRET_KEY_BASE`: `mix phx.gen.secret`
   - Настройте SSL/TLS через reverse proxy (nginx/caddy)
   - Настройте systemd service для автозапуска

## Дополнительная помощь

- Документация Phoenix: https://hexdocs.pm/phoenix/overview.html
- Документация Ecto: https://hexdocs.pm/ecto/getting-started.html
- Elixir School: https://elixirschool.com/ru/
- Elixir Forum: https://elixirforum.com/

## Контакты

При возникновении вопросов или проблем, создайте Issue в репозитории проекта.
