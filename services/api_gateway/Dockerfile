# ─── Build stage ──────────────────────────────────────────────────────────────
FROM golang:1.23-alpine AS builder

RUN apk add --no-cache gcc musl-dev
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=1 GOOS=linux go build -o api-gateway .

# ─── Run stage ────────────────────────────────────────────────────────────────
FROM alpine:3.20

RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY --from=builder /app/api-gateway .

EXPOSE 8080
CMD ["./api-gateway"]
