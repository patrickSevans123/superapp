# ─── Build stage ──────────────────────────────────────────────────────────────
FROM golang:1.23-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends gcc g++ libc6-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -o api-gateway .

# ─── Run stage ────────────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /app/api-gateway .
COPY --from=builder /app/data ./static-data

RUN useradd --system --uid 10001 --no-create-home --shell /sbin/nologin appuser
USER appuser

ENV STATIC_DATA_DIR=/app/static-data

EXPOSE 8080
CMD ["./api-gateway"]
