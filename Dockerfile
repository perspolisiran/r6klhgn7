# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM golang:1.26.3-alpine AS builder

ARG TARGETOS
ARG TARGETARCH

RUN apk update && apk add --no-cache make git

WORKDIR /src

RUN git clone --depth 1 https://github.com/PasarGuard/node.git .

RUN go mod download

RUN CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} make NAME=main build

RUN GOOS=${TARGETOS} GOARCH=${TARGETARCH} make install_xray


# ============================================================
# Runtime
# ============================================================

FROM alpine:latest

RUN apk update && apk add --no-cache \
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

# ------------------------------------------------------------
# PasarGuard Node settings
# ------------------------------------------------------------

ENV NODE_HOST=0.0.0.0
ENV SERVICE_PORT=62050
ENV SERVICE_PROTOCOL=grpc
ENV GENERATED_CONFIG_PATH=/var/lib/pg-node/generated

# ------------------------------------------------------------
# Certificate settings
#
# NODE_DOMAIN is intentionally NOT hard-coded.
#
# Railway / Installer can provide:
#
# NODE_DOMAIN=example.proxy.rlwy.net
#
# The certificate will be generated at container startup.
# ------------------------------------------------------------

ENV NODE_DOMAIN=localhost

ENV SSL_CERT_FILE=/app/certs/ssl_cert.pem
ENV SSL_KEY_FILE=/app/certs/ssl_key.pem

RUN mkdir -p \
    /app/certs \
    /var/lib/pg-node/generated

# ------------------------------------------------------------
# Startup script
# ------------------------------------------------------------

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 62050

ENTRYPOINT ["/entrypoint.sh"]
