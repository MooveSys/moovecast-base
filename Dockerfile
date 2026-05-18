# moovecast-base/Dockerfile
# Imagem base do Moovecast: datarhei/base (Alpine 3.16 + FFmpeg 5.1.3) + TSDuck v3.43
#
# ESTRATÉGIA:
# - Stage 1 (tsduck-builder): compila TSDuck v3.43 no Alpine 3.16 com patch para OpenSSL 1.1
#   O TSDuck v3.43 usa SSL_OP_IGNORE_UNEXPECTED_EOF (API OpenSSL 3+),
#   mas Alpine 3.16 tem OpenSSL 1.1.1. O patch envolve a chamada em #if.
# - Stage final: datarhei/base (Alpine 3.16 com FFmpeg 5.1.3 já funcional)
#   + cópia dos binários TSDuck compilados acima (mesma musl/OpenSSL 1.1)
#
# Resultado: imagem sem conflitos de libs e com FFmpeg + TSDuck funcionais

# ──────────────────────────────────────────────────────────────────────────────
# Stage 1: Compilar TSDuck v3.43 no Alpine 3.16 (OpenSSL 1.1.1 / musl 1.2.3)
# com patch para tornar SSL_OP_IGNORE_UNEXPECTED_EOF opcional
# ──────────────────────────────────────────────────────────────────────────────
FROM alpine:3.16 AS tsduck-builder

RUN apk add --no-cache \
        bash python3 git cmake make g++ musl-dev \
        linux-headers curl-dev openssl-dev zlib-dev readline-dev sed

RUN git clone --depth=1 --branch v3.43-4549 \
        https://github.com/tsduck/tsduck.git /src/tsduck

WORKDIR /src/tsduck

# Patch: envolver SSL_OP_IGNORE_UNEXPECTED_EOF em #if para OpenSSL 3+
# tsOpenSSL.cpp linha 126: só usa a opção se OPENSSL_VERSION_NUMBER >= 0x30000000L
RUN sed -i \
    's/::SSL_CTX_set_options(ssl_ctx, SSL_OP_IGNORE_UNEXPECTED_EOF);/#if OPENSSL_VERSION_NUMBER >= 0x30000000L\n    ::SSL_CTX_set_options(ssl_ctx, SSL_OP_IGNORE_UNEXPECTED_EOF);\n#endif/' \
    /src/tsduck/src/libtscore/system/unix/tsOpenSSL.cpp && \
    grep -A2 -B1 'OPENSSL_VERSION_NUMBER' /src/tsduck/src/libtscore/system/unix/tsOpenSSL.cpp | head -6

# Compilar TSDuck sem hardware-specific plugins e sem editline/docs
RUN make -j$(nproc) \
        NOPCSC=1 NODTAPI=1 NOEAGLE=1 NOSRT=1 NORIST=1 NOHIDES=1 NOVATEK=1 NOEDITLINE=1 \
        CXXFLAGS_EXTRA=-Wno-error && \
    make install \
        NOPCSC=1 NODTAPI=1 NOEAGLE=1 NOSRT=1 NORIST=1 NOHIDES=1 NOVATEK=1 NOEDITLINE=1 NODOC=1 && \
    strip /usr/bin/tsp 2>/dev/null || true && \
    /usr/bin/tsp --version 2>&1 && \
    echo "TSDuck builder OK (Alpine 3.16 / OpenSSL 1.1.1)"

# ──────────────────────────────────────────────────────────────────────────────
# Stage Final: datarhei/base (Alpine 3.16 + FFmpeg 5.1.3 funcional)
# + binários TSDuck compilados acima (mesma musl/OpenSSL 1.1)
# ──────────────────────────────────────────────────────────────────────────────
FROM datarhei/base:alpine-ffmpeg-latest

# Runtime deps do TSDuck que podem não estar no datarhei/base
RUN apk add --no-cache \
        readline libstdc++ libgcc curl ca-certificates

# TSDuck binários compilados no Alpine 3.16 (mesmas libs do runtime)
COPY --from=tsduck-builder /usr/bin/tsp          /usr/local/bin/tsp
COPY --from=tsduck-builder /usr/lib/libtsduck.so /usr/local/lib/libtsduck.so
COPY --from=tsduck-builder /usr/lib/libtscore.so /usr/local/lib/libtscore.so

RUN ldconfig /usr/local/lib 2>/dev/null || true && \
    /usr/local/bin/tsp --version 2>&1 && \
    echo "moovecast-base OK: FFmpeg + TSDuck prontos"

LABEL org.opencontainers.image.title="moovecast-base" \
      org.opencontainers.image.description="Moovecast base: datarhei/base (Alpine 3.16 + FFmpeg 5.1.3) + TSDuck 3.43 (EIT injection for ISDB-T)" \
      org.opencontainers.image.vendor="Moovesys" \
      org.opencontainers.image.version="1.0.0"
