#!/usr/bin/env bash
# Generates a throwaway self-signed CA + server + client cert/key for Lesson 09's
# TLS lab. Never commit the output — architecture-and-operations/certs/ is gitignored.
set -euo pipefail
CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/certs"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# 1. Self-signed CA
openssl genrsa -out ca.key 4096
openssl req -x509 -new -nodes -sha256 -days 3650 \
  -key ca.key -out ca.crt -subj "/O=Pulse Redis Lab/CN=Pulse Lab CA"

# 2. Server cert (SAN must match how clients connect: container name + localhost)
openssl genrsa -out redis.key 2048
openssl req -new -sha256 -key redis.key -out redis.csr \
  -subj "/O=Pulse Redis Lab/CN=redis-tls"
cat > redis.ext <<EOF
subjectAltName = DNS:redis-tls, DNS:localhost, IP:127.0.0.1
extendedKeyUsage = serverAuth,clientAuth
EOF
openssl x509 -req -sha256 -days 365 \
  -in redis.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out redis.crt -extfile redis.ext

# 3. Client cert (needed because tls-auth-clients yes requires mutual TLS)
openssl genrsa -out client.key 2048
openssl req -new -sha256 -key client.key -out client.csr \
  -subj "/O=Pulse Redis Lab/CN=pulse-client"
cat > client.ext <<EOF
extendedKeyUsage = clientAuth
EOF
openssl x509 -req -sha256 -days 365 \
  -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out client.crt -extfile client.ext

chmod 644 ca.crt redis.crt client.crt
chmod 600 ca.key redis.key client.key
rm -f redis.csr client.csr redis.ext client.ext
echo "Certs written to $CERT_DIR"
