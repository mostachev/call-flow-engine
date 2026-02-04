# Asterisk Compatibility Guide

## 🎯 Поддерживаемые версии Asterisk

### ✅ Минимальная версия: **Asterisk 12.0**

CallFlowEngine использует **Asterisk REST Interface (ARI)**, который был введен в Asterisk 12.

### 🌟 Рекомендуемые версии

| Версия | Статус | Рекомендация | Примечание |
|--------|--------|--------------|------------|
| **Asterisk 20+** | Current | ⭐⭐⭐⭐⭐ Отлично | Последняя стабильная, все фичи ARI |
| **Asterisk 18** | LTS | ⭐⭐⭐⭐⭐ Отлично | Long Term Support до 2025 |
| **Asterisk 16** | Old LTS | ⭐⭐⭐⭐ Хорошо | LTS закончена, но стабильная |
| **Asterisk 13-15** | EOL | ⭐⭐⭐ Работает | End of Life, обновитесь |
| **Asterisk 12** | EOL | ⭐⭐ Минимум | Первая с ARI, очень старая |

---

## 🔍 Требуемые функции ARI

CallFlowEngine использует следующие возможности ARI:

### 1. WebSocket Events (с Asterisk 12+)
```
ws://asterisk:8088/ari/events?app=callflow_elixir
```

**Поддерживаемые события:**
- ✅ `StasisStart` - начало звонка
- ✅ `StasisEnd` - завершение звонка
- ✅ `ChannelStateChange` - изменение состояния канала
- ✅ `ChannelDestroyed` - уничтожение канала
- ✅ `ChannelVarset` - установка переменной
- ✅ `BridgeEnter` - вход в бридж (опционально)

**Минимальная версия:** Asterisk 12.0

### 2. HTTP REST API (с Asterisk 12+)
```
http://asterisk:8088/ari/channels/{channelId}
```

**Используемые endpoints (опционально):**
- `GET /ari/channels/{channelId}` - информация о канале
- `POST /ari/channels/{channelId}/answer` - ответить на звонок
- `DELETE /ari/channels/{channelId}` - повесить трубку

**Минимальная версия:** Asterisk 12.0

### 3. Stasis Dialplan Application (с Asterisk 12+)
```
exten => _X.,1,Stasis(callflow_elixir)
```

**Минимальная версия:** Asterisk 12.0

---

## 📊 Версии по возможностям

### Asterisk 12 (Минимум)
✅ Базовые ARI события  
✅ WebSocket подключение  
✅ Stasis application  
⚠️ Ограниченная функциональность  
⚠️ Старые баги ARI

### Asterisk 13-15
✅ Улучшенный ARI  
✅ Больше событий  
✅ Стабильнее WebSocket  
⚠️ EOL (End of Life)

### Asterisk 16 (LTS)
✅ Production-ready ARI  
✅ Все нужные события  
✅ Стабильный WebSocket  
✅ Хорошая документация  
⭐ **Рекомендуется как минимум**

### Asterisk 18+ (Current LTS)
✅ Современный ARI  
✅ Улучшенная производительность  
✅ Новые фичи  
✅ Long Term Support  
⭐⭐ **Лучший выбор для production**

### Asterisk 20+
✅ Последняя версия  
✅ Все современные фичи  
✅ Лучшая производительность  
⭐⭐⭐ **Для новых проектов**

---

## 🔧 Настройка Asterisk

### Конфигурация ARI (`/etc/asterisk/ari.conf`)

**Минимальная (Asterisk 12+):**
```ini
[general]
enabled = yes

[callflow]
type = user
password = your_password
password_format = plain
```

**Рекомендуемая (Asterisk 16+):**
```ini
[general]
enabled = yes
pretty = yes
auth_realm = Asterisk ARI

[callflow]
type = user
read_only = no
password = your_secure_password
password_format = plain
```

### HTTP Server (`/etc/asterisk/http.conf`)

**Минимальная:**
```ini
[general]
enabled = yes
bindaddr = 0.0.0.0
bindport = 8088
```

**Рекомендуемая (с TLS):**
```ini
[general]
enabled = yes
bindaddr = 0.0.0.0
bindport = 8088

; TLS (опционально)
tlsenable = yes
tlsbindaddr = 0.0.0.0:8089
tlscertfile = /etc/asterisk/keys/asterisk.pem
tlsprivatekey = /etc/asterisk/keys/asterisk.key
```

### Dialplan (`/etc/asterisk/extensions.conf`)

**Базовый (работает со всеми версиями):**
```ini
[from-internal]
exten => _X.,1,NoOp(Outbound call)
 same => n,Set(intNum=${CALLERID(num)})
 same => n,Stasis(callflow_elixir)
 same => n,Hangup()

[from-external]
exten => _X.,1,NoOp(Inbound call)
 same => n,Set(extNum=${EXTEN})
 same => n,Stasis(callflow_elixir)
 same => n,Hangup()
```

**Продвинутый (Asterisk 16+):**
```ini
[from-internal]
exten => _X.,1,NoOp(Outbound: ${CALLERID(num)} -> ${EXTEN})
 same => n,Set(CHANNEL(language)=ru)
 same => n,Set(__intNum=${CALLERID(num)})
 same => n,Set(__direction=outbound)
 same => n,Stasis(callflow_elixir,outbound,${EXTEN})
 same => n,Hangup()

[from-external]
exten => _X.,1,NoOp(Inbound: ${CALLERID(num)} -> ${EXTEN})
 same => n,Set(CHANNEL(language)=ru)
 same => n,Set(__extNum=${CALLERID(num)})
 same => n,Set(__direction=inbound)
 same => n,Stasis(callflow_elixir,inbound,${EXTEN})
 same => n,Hangup()
```

---

## 🧪 Проверка совместимости

### 1. Проверка версии Asterisk

```bash
asterisk -V
# Должно вывести: Asterisk 12.0 или выше
```

### 2. Проверка поддержки ARI

```bash
# Войдите в Asterisk CLI
asterisk -rx "ari show status"

# Должно вывести:
# ARI Status:
# enabled: True
```

### 3. Проверка HTTP Server

```bash
# Проверьте что порт открыт
netstat -tulpn | grep 8088

# Или через curl
curl http://localhost:8088/ari/api-docs/resources.json
```

### 4. Тест WebSocket подключения

```bash
# Используйте wscat (установите: npm install -g wscat)
wscat -c "ws://localhost:8088/ari/events?app=test&api_key=callflow:your_password"
```

---

## ⚠️ Известные проблемы

### Asterisk 12-13: WebSocket нестабилен
**Проблема:** Частые disconnects  
**Решение:** CallFlowEngine автоматически переподключается (exponential backoff)

### Asterisk 12-15: Отсутствуют некоторые события
**Проблема:** Не все события ARI доступны  
**Решение:** Проект использует только базовые события

### Все версии: linkedid может быть пустым
**Проблема:** В некоторых сценариях linkedid = null  
**Решение:** Fallback на channel.id в EventRouter

---

## 📚 Дополнительная информация

### Документация Asterisk ARI

- **Asterisk 12:** https://wiki.asterisk.org/wiki/display/AST/Asterisk+12+Documentation
- **Asterisk 16:** https://wiki.asterisk.org/wiki/display/AST/Asterisk+16+Documentation
- **Asterisk 18:** https://wiki.asterisk.org/wiki/display/AST/Asterisk+18+Documentation
- **ARI Reference:** https://wiki.asterisk.org/wiki/display/AST/Asterisk+REST+Interface

### История ARI

| Версия | Год | Событие |
|--------|-----|---------|
| Asterisk 12 | 2013 | Введение ARI |
| Asterisk 13 | 2014 | Улучшения ARI |
| Asterisk 16 | 2018 | LTS с зрелым ARI |
| Asterisk 18 | 2020 | Current LTS |
| Asterisk 20 | 2022 | Последняя стабильная |

---

## ✅ Рекомендации

### Для Production

1. **Используйте Asterisk 18+ LTS**
   - Стабильная, поддерживаемая версия
   - Все фичи ARI работают отлично
   - Long Term Support

2. **Минимум Asterisk 16**
   - Если не можете обновиться до 18+
   - Всё ещё достаточно стабильная

3. **Избегайте Asterisk 12-15**
   - Очень старые версии
   - End of Life
   - Проблемы с безопасностью

### Для Development/Testing

- **Asterisk 18+** - идеально
- **Asterisk 16+** - допустимо
- **Asterisk 12+** - только для тестирования совместимости

### Апгрейд с старой версии

Если у вас Asterisk < 16:

```bash
# 1. Backup текущей конфигурации
tar -czf /backup/asterisk-config.tar.gz /etc/asterisk

# 2. Backup базы данных (если используется)
mysqldump asterisk > /backup/asterisk-db.sql

# 3. Установите новую версию
# (зависит от вашей ОС)

# 4. Восстановите конфигурацию
# (проверьте совместимость файлов конфигурации!)

# 5. Тестируйте перед production
```

---

## 🎯 Итого

**Минимальная версия:** Asterisk 12.0  
**Рекомендуемая версия:** Asterisk 18+ (LTS)  
**Оптимальная версия:** Asterisk 20+

**CallFlowEngine работает со всеми версиями Asterisk 12+**, но для production рекомендуется использовать Asterisk 16 или новее.

---

**Последнее обновление:** 2026-02-04  
**Версия документа:** 1.0
