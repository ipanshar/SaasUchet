# Saas Uchet

Чистый монорепо-старт для мобильного приложения на `Flutter` и бекенда на `Go`.

## Что внутри

- `backend/` - HTTP API на стандартной библиотеке Go.
- `mobile/` - Flutter-клиент с экраном проверки соединения с API.

## Структура

```text
.
|-- backend
|   |-- cmd/api
|   `-- internal
|-- mobile
|   |-- lib
|   `-- test
|-- .editorconfig
|-- .gitignore
`-- README.md
```

## Быстрый старт

### 1. PostgreSQL

Для локальной разработки добавлен `compose.yaml`:

```bash
docker compose up -d postgres
```

По умолчанию база поднимается на `localhost:5432`, база данных `saas_uchet`, пользователь `postgres`, пароль `postgres`.

### 2. Бекенд

```bash
cd backend
cp .env.example .env
go run ./cmd/api
```

По умолчанию сервер стартует на `http://localhost:8080`, а health-check доступен по `GET /api/v1/health`.

При старте бекенд автоматически подключается к PostgreSQL и создаёт таблицы `users` и `auth_sessions`, если их ещё нет.

### 3. Мобильное приложение

В репозитории можно использовать локальный `Flutter SDK` из `.tools/flutter-sdk`.

Для web dev-режима из этого репозитория:

```bash
./scripts/run-mobile-web-dev.sh
```

Если у тебя установлен системный `Flutter SDK` и нужны мобильные платформы:

```bash
cd mobile
flutter create --platforms=android,ios .
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Подсказки по URL API:

- Android emulator: `http://10.0.2.2:8080`
- iOS simulator: `http://localhost:8080`
- Физическое устройство: `http://<IP_вашего_компьютера>:8080`

## Переменные окружения бекенда

Смотри `backend/.env.example`.

## Что уже готово

- Чистая структура проекта для дальнейшего роста.
- Базовый API с CORS, graceful shutdown и health-check.
- Flutter-клиент с регистрацией, логином и экраном профиля.

## Auth API

Бекенд уже содержит базовую регистрацию и авторизацию по номеру телефона.

### Регистрация

`POST /api/v1/auth/register`

```json
{
  "full_name": "Иван Петров",
  "phone": "+7 701 123 45 67",
  "password": "StrongPass123"
}
```

### Логин

`POST /api/v1/auth/login`

```json
{
  "phone": "+7 701 123 45 67",
  "password": "StrongPass123"
}
```

### Текущий пользователь

`GET /api/v1/auth/me`

Заголовок:

```text
Authorization: Bearer <access_token>
```

### Профиль пользователя

`GET /api/v1/profile`

Возвращает текущий профиль по `Bearer` токену.

`PUT /api/v1/profile`

```json
{
  "full_name": "Иван Сергеевич Петров",
  "phone": "+7 777 111 22 33",
  "password": "NewStrongPass123"
}
```

Поле `password` можно не передавать, если менять пароль не нужно.

`DELETE /api/v1/profile`

Удаляет пользователя и связанные auth-сессии.

### Важно

- Авторизация выполняется по номеру телефона и паролю.
- Пользователи, хэши паролей и auth-сессии теперь сохраняются в PostgreSQL.
- Телефон нормализуется и хранится в формате `+77011234567`.
- Номер в формате `87011234567` автоматически приводится к `+77011234567`.
- Пароль в базе хранится не в открытом виде, а в виде PBKDF2-SHA256 хэша с солью.
- Flutter web/dev UI уже подключён к `register`, `login`, `profile update`, `profile delete` и `health-check`.
