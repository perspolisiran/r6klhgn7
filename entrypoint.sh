#!/bin/sh

set -e

CERT_DIR="/app/certs"
CERT_FILE="${SSL_CERT_FILE:-/app/certs/ssl_cert.pem}"
KEY_FILE="${SSL_KEY_FILE:-/app/certs/ssl_key.pem}"

DOMAIN="${NODE_DOMAIN:-localhost}"

echo "========================================"
echo "Trendify PasarGuard Node"
echo "========================================"
echo "NODE_DOMAIN: ${DOMAIN}"
echo "SERVICE_PORT: ${SERVICE_PORT:-62050}"
echo "========================================"

mkdir -p "$CERT_DIR"

# Generate certificate for the actual runtime domain
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then

    echo "Generating TLS certificate for: ${DOMAIN}"

    openssl req \
        -x509 \
        -newkey ec \
        -pkeyopt ec_paramgen_curve:P-256 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -days 3650 \
        -nodes \
        -subj "/CN=${DOMAIN}" \
        -addext "subjectAltName = DNS:${DOMAIN},DNS:localhost,IP:127.0.0.1"

    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"

    echo "TLS certificate generated successfully."

else

    echo "Existing TLS certificate found."

fi

echo "Starting PasarGuard Node..."

exec /app/main
