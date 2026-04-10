# Используем официальный образ Python
FROM python:3.11-slim

# Устанавливаем рабочую директорию
WORKDIR /app

# Устанавливаем uv
RUN pip install --no-cache-dir uv

# Копируем файлы зависимостей
COPY pyproject.toml uv.lock README.md ./

# Устанавливаем зависимости через uv
RUN uv sync --frozen

# Копируем код приложения
COPY backend/ ./backend/

# Копируем frontend
COPY frontend/ ./frontend/

# Копируем данные
COPY data/ ./data/

# Открываем порт
EXPOSE 8000

# Запускаем приложение через uv
CMD ["uv", "run", "uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]