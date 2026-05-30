FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl && \
    rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./
RUN pip install --no-cache-dir -e . && pip install schedule

COPY src/ ./src/
COPY scheduler_entry.py ./
COPY data/ ./data/

CMD ["python", "scheduler_entry.py"]
