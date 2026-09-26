# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM golang:1.26.3-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

RUN apk add --no-cache make git openssl

WORKDIR /src

RUN git clone --depth 1 https://github.com/PasarGuard/node.git .

RUN go mod download

RUN CGO_ENABLED=0 \
    GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH} \
    make NAME=main build

RUN GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH} \
    make install_xray


FROM alpine:latest

RUN apk add --no-cache \
    wireguard-tools \
    nftables \
    iproute2 \
    procps \
    openssl \
    ca-certificates

WORKDIR /app

COPY --from=builder /src/main /app/main
COPY --from=builder /usr/local/bin/xray /usr/local/bin/xray
COPY --from=builder /usr/local/share/xray /usr/local/share/xray

ENV NODE_HOST=0.0.0.0
ENV SERVICE_PORT=62050
ENV SERVICE_PROTOCOL=grpc
ENV GENERATED_CONFIG_PATH=/var/lib/pg-node/generated

ENV SSL_CERT_FILE=/app/certs/ssl_cert.pem
ENV SSL_KEY_FILE=/app/certs/ssl_key.pem

RUN mkdir -p \
    /app/certs \
    /var/lib/pg-node/generated

# Generate a certificate that is NOT tied to a Railway domain.
RUN openssl req \
    -x509 \
    -newkey ec \
    -pkeyopt ec_paramgen_curve:P-256 \
    -keyout /app/certs/ssl_key.pem \
    -out /app/certs/ssl_cert.pem \
    -days 3650 \
    -nodes \
    -subj "/CN=Trendify-PasarGuard-Node" \
    -addext "subjectAltName=DNS:Trendify-PasarGuard-Node,DNS:localhost,IP:127.0.0.1"

RUN chmod 600 /app/certs/ssl_key.pem && \
    chmod 644 /app/certs/ssl_cert.pem

EXPOSE 62050

ENTRYPOINT ["./main"]
