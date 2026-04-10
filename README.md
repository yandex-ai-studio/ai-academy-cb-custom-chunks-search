# AI Search Demo - Пользовательские чанки

Демо-приложение для демонстрации разницы между автоматическим чанкованием и использованием заранее подготовленных пользовательских чанков в формате JSON Lines в Yandex Cloud AI Studio.

## Что это?

Простое приложение, которое показывает разницу между:
- **Режим A**: автоматическое чанкование (платформа сама разбивает документ)
- **Режим B**: пользовательские чанки (вы контролируете структуру данных)

## Структура проекта

```
chunk_search/
├── .env.example             # Пример конфигурации
├── pyproject.toml           # Зависимости проекта
├── Dockerfile               # Docker конфигурация
├── docker-compose.yml       # Docker Compose конфигурация
├── backend/
│   ├── main.py              # FastAPI сервер
│   └── .gitignore
├── frontend/
│   └── index.html           # Веб-интерфейс
├── data/
│   ├── faq.txt              # FAQ для режима A
│   └── faq_chunks.jsonl     # FAQ для режима B
└── README.md
```

## Быстрый старт

### 1. Установка зависимостей

```bash
# Установить зависимости и создать виртуальное окружение
uv sync

# Активировать окружение
source .venv/bin/activate  # macOS/Linux
```

> **Примечание**:
> - Установите `uv` с помощью команды `curl -LsSf https://astral.sh/uv/install.sh | sh`
> - Команда `uv sync` автоматически создаёт виртуальное окружение и устанавливает все зависимости из `pyproject.toml`

### 2. Настройка

Создайте файл `.env` в корне проекта:

```bash
# Скопировать образец
cp .env.example .env

# Отредактировать и добавить свои credentials
nano .env  # или vim .env
```

Содержимое `.env`:

```bash
YANDEX_API_KEY=your_api_key_here
YANDEX_FOLDER_ID=your_folder_id_here
YANDEX_CLOUD_MODEL=qwen3-235b-a22b-fp8/latest
SERVER_PORT=8000
```

### 3. Запуск

#### Вариант 1: Локальный запуск

```bash
# Из корня проекта
uv run uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

Приложение будет доступно по адресу: **http://localhost:8000**

#### Вариант 2: Запуск через Docker Compose

```bash
# Убедитесь, что .env файл создан в корне проекта (см. шаг 2)

# Запустить приложение
docker compose up -d

# Просмотр логов
docker compose logs -f
```

Приложение будет доступно по адресу: **http://localhost:8000**

Для остановки:
```bash
docker compose down
```

## Использование

### Веб-интерфейс

1. Откройте http://localhost:8000 в браузере.
2. Нажмите кнопку **Загрузить данные и создать индексы**.
3. Дождитесь создания индексов (1-2 минуты).
4. Выберите режим **A** или **B**.
5. Введите вопрос. Например: **Как создать виртуальную машину?**.
6. Нажмите **Найти**.
7. Сравните результаты между режимами.

**Совет**: Используйте кнопку **Удалить индексы** для удаления индексов из Vector Store и загруженных файлов.

### API

#### Инициализация индексов

```bash
curl -X POST http://localhost:8000/api/initialize
```

#### Сброс индексов

```bash
curl -X POST http://localhost:8000/api/reset
```

#### Поиск

```bash
curl -X POST http://localhost:8000/api/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Как создать виртуальную машину?",
    "mode": "chunks",
    "max_num_results": 3
  }'
```

Параметры:
- `query` — текст запроса;
- `mode` — режим поиска: `"auto"` или `"chunks"`;
- `max_num_results` — максимальное количество результатов поиска.

## Демо сценарий

### Режим A: автоматическое чанкование

1. Выберите **Режим A**.
2. Введите: **Какие операционные системы поддерживаются?**.
3. Результат: ответ модели, используемые фрагменты со `score`, полный ответ в JSON.

### Режим B: пользовательские чанки

1. Выберите **Режим B**.
2. Введите: **Какие операционные системы поддерживаются?**.
3. Результат: более точный ответ, фрагменты с высоким score (0.85-0.95), полный ответ в JSON. Вопрос и ответ в одном чанке.

### Вывод

Пользовательские чанки обеспечивают:
- Сохранение логической целостности (вопрос + ответ).
- Высокий `score` релевантности.
- Точные ответы модели.
- Меньший расход токенов за счёт отсутствия дублирования контекста и более точного попадания в релевантные фрагменты.

## Как это работает

### Архитектура

- **Асинхронные операции**: использование `AsyncOpenAI` для параллельной загрузки файлов и создания индексов.
- **Параллельное выполнение**: оба режима (A и B) создаются одновременно через `asyncio.gather()`.
- **Настраиваемый поиск**: возможность изменить количество результатов поиска.

### Ключевое отличие в коде

**Режим A** (автоматическое чанкование):
```python
# Загрузка файла
file_id = await upload_file(AUTO_MODE_FILE, "text/plain")

# Создание Vector Store с автоматическим чанкованием
vector_store = await async_client.vector_stores.create(
    name="FAQ Auto Chunking",
    file_ids=[file_id],
    expires_after={"anchor": "last_active_at", "days": 1},
    chunking_strategy={
        "type": "static",
        "static": {
            "max_chunk_size_tokens": 800,
            "chunk_overlap_tokens": 400
        }
    }
)
```

**Режим B** (пользовательские чанки):
```python
# Загрузка файла с указанием формата chunks
file_id = await upload_file(
    CHUNKS_MODE_FILE,
    "application/jsonlines",
    extra_body={"format": "chunks"}  # ← Ключевое!
)

# Создание Vector Store без автоматического чанкования
vector_store = await async_client.vector_stores.create(
    name="FAQ Custom Chunks",
    file_ids=[file_id],
    expires_after={"anchor": "last_active_at", "days": 1}
)
```

### Формат JSONL

Файл `data/faq_chunks.jsonl`:
```jsonl
{"body": "Вопрос: ...\nОтвет: ..."}
{"body": "Вопрос: ...\nОтвет: ..."}
```

Каждая строка — отдельный чанк с полем `body`.

## Данные

В `data/` используется простой FAQ

## Разработка

### Структура backend

- `main.py` — весь код в одном файле.
- Асинхронные операции для загрузки и создания индексов.
- Параллельное создание обоих режимов.
- Endpoints:
  - `GET /` - веб-интерфейс;
  - `GET /api/stores` - ID Vector Stores;
  - `GET /api/data/{mode}` - просмотр исходных файлов;
  - `POST /api/initialize` - создание индексов (параллельно);
  - `POST /api/reset` - удаление индексов и файлов;
  - `POST /api/search` - поиск с настраиваемым количеством результатов.

### Ключевые функции

- `upload_file()` — асинхронная загрузка файлов;
- `wait_for_vector_store()` — асинхронное ожидание готовности индекса;
- `create_auto_chunking_store()` — создание индекса с автоматическим чанкованием;
- `create_custom_chunks_store()` — создание индекса с пользовательскими чанками;
- `search_in_store()` - поиск с настраиваемым `max_num_results`.

## Документация

- [Yandex Cloud AI Studio](https://yandex.cloud/ru/docs/ai-studio/)
- [Vector Store API](https://yandex.cloud/ru/docs/ai-studio/concepts/search/vectorstore)
- [Создание агента с чанками](https://yandex.cloud/ru/docs/ai-studio/operations/agents/create-prechunked-search-agent)