#!/usr/bin/env bash
# build-tsduck.sh — Compila TSDuck no Alpine 3.19 e extrai os binários para dist/
# Executar localmente para gerar os binários antes do push da imagem base.
#
# Uso:
#   bash build-tsduck.sh
#
# Saída: ./dist/
#   tsp, libtsduck.so, libtscore.so, libcrypto.so.3, libssl.so.3

set -e

TSDUCK_VERSION="v3.43-4549"
DIST="$(pwd)/dist"

echo "▶ Compilando TSDuck ${TSDUCK_VERSION} no Alpine 3.19..."
mkdir -p "$DIST"

docker run --rm \
  -v "${DIST}:/dist" \
  -e TSDUCK_VERSION="${TSDUCK_VERSION}" \
  alpine:3.19 sh -c '
    set -ex

    apk add --no-cache \
      bash python3 git cmake make g++ musl-dev \
      linux-headers curl-dev openssl-dev zlib-dev readline-dev

    git clone --depth=1 --branch "${TSDUCK_VERSION}" \
      https://github.com/tsduck/tsduck.git /src/tsduck

    cd /src/tsduck

    make -j$(nproc) \
      NOPCSC=1 NODTAPI=1 NOEAGLE=1 NOSRT=1 NORIST=1 NOHIDES=1 NOVATEK=1 NOEDITLINE=1

    make install \
      NOPCSC=1 NODTAPI=1 NOEAGLE=1 NOSRT=1 NORIST=1 NOHIDES=1 NOVATEK=1 NOEDITLINE=1 NODOC=1

    strip /usr/bin/tsp 2>/dev/null || true

    echo "=== Copiando binários para /dist ==="
    cp /usr/bin/tsp                /dist/tsp
    cp /usr/lib/libtsduck.so       /dist/libtsduck.so
    cp /usr/lib/libtscore.so       /dist/libtscore.so
    cp /usr/lib/libcrypto.so.3     /dist/libcrypto.so.3 2>/dev/null || true
    cp /usr/lib/libssl.so.3        /dist/libssl.so.3    2>/dev/null || true
    ls -lh /dist/
    tsp --version
    echo "=== BUILD OK ==="
'

echo ""
echo "✅ Binários em: $DIST"
ls -lh "$DIST"
