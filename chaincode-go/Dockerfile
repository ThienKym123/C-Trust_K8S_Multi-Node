# --- Stage 1: Build the Go chaincode ---
FROM golang:1.23 AS builder
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o /chaincode .

# --- Stage 2: Create final runtime image ---
FROM alpine:3.18
RUN apk add --no-cache ca-certificates bash  # Thêm bash
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=builder /chaincode /chaincode
COPY docker/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
ENV CORE_CHAINCODE_ADDRESS=0.0.0.0:9999
EXPOSE 9999
USER appuser
ENTRYPOINT ["/docker-entrypoint.sh"]
