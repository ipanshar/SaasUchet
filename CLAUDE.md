# SaasUchet — CLAUDE.md

Контекст для AI-агентов (Claude Code, OpenAI Codex и др.) о структуре, архитектуре и соглашениях проекта.

---

## Обзор проекта

Мобильное приложение для учёта бизнеса — аналог «Мой склад» + AmoCRM, ориентирован на рынок Казахстана.

- Язык интерфейса: **русский**
- Валюта: **тенге ₸ (KZT)**
- Идентификаторы: **БИН** (бизнес), **ИИН** (физлицо)
- Статус: активная разработка, версия `0.1.0`
- Параллельная разработка: этот проект ведётся одновременно агентом **OpenAI Codex**. При изменениях предпочитать аддитивные правки; не ломать существующие контракты без обсуждения.

---

## Технологический стек

| Слой | Технология |
|---|---|
| Мобильное приложение | Flutter (Dart), SDK ≥ 3.4.0 |
| Бэкенд | Go 1.25, стандартная библиотека `net/http` |
| База данных | PostgreSQL 17 |
| Локальная инфраструктура | Docker Compose (`compose.yaml` в корне) |
| Дизайн | Figma → `figma/DESIGN_SYSTEM.md` |

---

## Структура репозитория

```
SaasUchet/
├── mobile/          # Flutter-приложение
├── backend/         # Go-бэкенд
├── figma/           # Дизайн-система (DESIGN_SYSTEM.md)
├── scripts/         # Вспомогательные скрипты
├── compose.yaml     # Docker Compose (только PostgreSQL)
└── CLAUDE.md        # Этот файл
```

---

## Flutter — архитектура

### Паттерн: Clean Architecture + Gateway

```
lib/
├── main.dart
├── app/app.dart                     # Корневой виджет, роутинг на старте
├── core/
│   ├── config/api_config.dart       # Базовый URL (платформозависимый)
│   ├── network/api_exception.dart   # Кастомные исключения
│   └── widgets/                     # Общие UI-компоненты (пусто, зарезервировано)
└── features/
    ├── auth/                        # Аутентификация
    │   ├── data/auth_api_client.dart
    │   ├── domain/{auth_gateway, auth_session, company_profile, user_profile}.dart
    │   └── presentation/auth_screen.dart
    ├── business/                    # Основной модуль
    │   ├── data/business_api_client.dart
    │   ├── domain/business_gateway.dart  # Все контракты бизнес-API
    │   └── presentation/
    │       ├── business_shell.dart       # Главный файл (1300+ строк, использует part)
    │       ├── business_models.dart      # part of business_shell
    │       ├── business_widgets.dart     # part of business_shell
    │       ├── dashboard_screen.dart     # part of business_shell
    │       ├── crm_screen.dart           # part of business_shell
    │       ├── warehouse_screen.dart     # part of business_shell
    │       ├── finance_screen.dart       # part of business_shell
    │       ├── more_screen.dart          # part of business_shell
    │       ├── onboarding_flow.dart      # part of business_shell
    │       └── profile_editor_screen.dart
    ├── health/                      # Заглушка, не реализован
    └── profile/                     # Заглушка, не реализован
```

### Слои

- **Presentation** — `StatefulWidget` + `setState`, никаких BLoC/Riverpod/Provider/GetX
- **Domain** — абстрактные `Gateway`-интерфейсы + модели данных
- **Data** — `ApiClient`, реализующий `Gateway`, делает HTTP-запросы

### Стейт-менеджмент

Только `setState`. Никакой внешней библиотеки пока нет. **Не добавлять без обсуждения.**

### Роутинг

`Navigator.of(context).push(MaterialPageRoute(...))` — без named routes и go_router.

### Сеть

- HTTP-клиент: пакет `http: ^1.2.2`
- Таймаут: 8 секунд
- Auth: Bearer token в заголовке `Authorization`
- JSON: ручная сериализация (нет `json_serializable` / Freezed)
- Базовый URL (`api_config.dart`):
  - Android emulator → `http://10.0.2.2:8080`
  - iOS simulator / Web → `http://localhost:8080`
  - Override через env-переменную `API_BASE_URL`

### Flutter — соглашения

- Одинарные кавычки (`'`)
- Material Design 3 (`useMaterial3: true`)
- Сериализация вручную — без кодогенерации
- Приватные вспомогательные классы внутри `business_shell` именуются с `_` (напр. `_Client`, `_Product`)

---

## Дизайн-система

Полная спецификация: `figma/DESIGN_SYSTEM.md`

### Цвета

| Роль | HEX |
|---|---|
| Primary (бренд) | `#00A86B` (изумрудный) |
| Primary Hover | `#008F5B` |
| Background | `#F7FAF8` (светло-мятный) |
| Text Primary | `#0F172A` |
| Border | `#E2E8F0` |
| Success | `#16A34A` |
| Warning | `#F59E0B` |
| Error | `#EF4444` |
| Info | `#3B82F6` |

### Типографика и компоненты

- Шрифт: **SF Pro Display** (системный)
- Border radius: **18px** (поля, кнопки, карточки)
- Кнопки: padding `16px` вертикальный / `20px` горизонтальный, `fontWeight: 700`
- Карточки: elevation 0

---

## Go — архитектура бэкенда

### Структура

```
backend/
├── cmd/api/main.go                      # Точка входа
└── internal/
    ├── auth/
    │   ├── handler.go                   # HTTP-обработчики
    │   ├── service.go                   # Бизнес-логика, управление сессиями
    │   ├── store.go                     # Store-интерфейс
    │   ├── postgres_store.go            # Реализация для PostgreSQL
    │   ├── model.go                     # Модели данных
    │   ├── password.go                  # PBKDF2-SHA256
    │   ├── errors.go                    # Кастомные ошибки
    │   └── service_test.go
    ├── business/
    │   ├── handler.go
    │   ├── store.go
    │   ├── postgres_store.go            # ~2390 строк, все бизнес-запросы
    │   ├── model.go
    │   └── handler_test.go
    ├── config/config.go                 # Конфигурация через env
    ├── database/
    │   ├── postgres.go                  # Подключение + автоприменение схем
    │   └── schema/
    │       ├── 001_auth.sql
    │       └── 002_business_core.sql
    ├── http/
    │   ├── router.go                    # Регистрация всех маршрутов
    │   └── middleware.go                # CORS, логирование, recovery
    ├── health/handler.go
    └── response/response.go             # JSON-хелперы
```

### Слои

**Handler → Service → Store**

- `Store` — интерфейс с двумя реализациями: `MemoryStore` (тесты) и `PostgresStore` (прод)
- Зависимости инжектируются через конструкторы

### Go — соглашения

- **ORM не используется**. Только сырой SQL + pgx (`github.com/jackc/pgx/v5`)
- Паттерн валидации: `NormalizeXInput()` → `ValidateXInput()`
- Аутентификация: **session token** (не JWT). Токен = Base64(32 random bytes), TTL 72ч
- Пароли: **PBKDF2-SHA256** (120 000 итераций), реализован вручную в `auth/password.go`
- HTTP: стандартный `net/http.ServeMux`, без gin/chi/echo
- Ответы: `response.JSON()` / `response.Error()` из `internal/response`
- Таймауты запросов к БД: 5 секунд по умолчанию

---

## База данных

### Миграции

- Встроенные SQL-файлы через `go:embed schema/*.sql`
- Применяются автоматически при старте (`applySchema()`)
- Идемпотентны: `CREATE TABLE IF NOT EXISTS`
- **Без goose/migrate** — только кастомный парсер SQL
- Новые миграции: создавать файл `003_*.sql`, `004_*.sql` и т.д.

### Схема

- `001_auth.sql` — таблицы `users`, `auth_sessions`
- `002_business_core.sql` — `companies`, `clients`, `products`, `inventory_documents`, `money_documents`, `accounts`

### Подключение (локально)

```
host: localhost:5432
db:   saas_uchet
user: algotrade
pass: algotrade
```

Docker: `docker compose up -d` (файл `compose.yaml` в корне)

---

## API — полный список эндпоинтов

Базовый путь: `/api/v1`

| Метод | Путь | Описание |
|---|---|---|
| GET | `/health` | Проверка работоспособности |
| POST | `/auth/register` | Регистрация (full_name, phone, password) |
| POST | `/auth/login` | Вход (phone, password) → access_token |
| GET | `/auth/me` | Текущий пользователь |
| GET/PUT/DELETE | `/profile` | Профиль пользователя |
| GET | `/business/overview` | Данные для дашборда |
| GET/POST | `/business/clients` | Список / создание клиента |
| PUT/DELETE | `/business/clients/{id}` | Обновление / удаление |
| GET/POST | `/business/products` | Список / создание товара |
| PUT/DELETE | `/business/products/{id}` | Обновление / удаление |
| GET/POST | `/business/inventory-documents` | Документы склада |
| GET | `/business/inventory-documents/{id}` | Детали документа |
| GET/POST | `/business/accounts` | Счета / кассы |
| POST | `/business/money-operations` | Денежная операция |
| GET | `/business/money-documents` | Денежные документы |
| GET | `/business/money-documents/{id}` | Детали документа |

Авторизация: `Authorization: Bearer <token>` для всех `/business/*` и `/profile`.

---

## Реализованные фичи (Flutter)

| Модуль | Статус |
|---|---|
| Аутентификация (телефон + пароль) | Готово |
| Онбординг (3 слайда) | Готово |
| Дашборд (KPI, график продаж) | Готово |
| CRM (клиенты, сегменты, долги) | Готово |
| Склад (товары, документы, штрихкоды) | Готово |
| Финансы (счета, операции, отчёты) | Готово |
| Профиль компании | Готово |
| Health-модуль | Заглушка |
| Profile-фича (отдельная) | Заглушка |

---

## Локальная разработка

```bash
# 1. Поднять БД
docker compose up -d

# 2. Запустить бэкенд (из папки backend/)
go run ./cmd/api

# 3. Запустить мобильное приложение (из папки mobile/)
flutter run
```

Конфигурация бэкенда: `backend/.env` (пример: `backend/.env.example`).

---

## Важные правила (не нарушать без обсуждения)

1. **Не добавлять ORM** (gorm, ent и т.д.) — используется сырой SQL
2. **Не добавлять state management** в Flutter (BLoC, Riverpod, Provider) — пока `setState`
3. **Не менять формат токена** — клиент и сервер ожидают Bearer session token
4. **Не ломать существующие API** — мобильное приложение жёстко завязано на контракты
5. **Новые SQL-схемы** — только через новый файл `00N_*.sql`, не редактировать существующие
6. **Кодогенерацию не вводить** без договорённости (`json_serializable`, `freezed` и т.д.)
7. **Параллельный агент Codex** — возможны изменения от него; перед крупными рефакторингами проверять git log
