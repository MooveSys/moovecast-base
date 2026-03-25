# moovecast-base/Dockerfile  
# Imagem base do Moovecast: Alpine 3.19 + FFmpeg (datarhei) + TSDuck
#
# ESTRATÉGIA:
# - Stage 1 (ffmpeg-extract): copia os binários FFmpeg do datarhei/base
# - Stage 2 (tsduck-builder): compila TSDuck no Alpine 3.19 (OpenSSL 3 nativo)
# - Stage final: Alpine 3.19 limpo + FFmpeg + TSDuck
#
# Resultado: imagem base unificada sem conflitos de versões de libs

# ──────────────────────────────────────────────────────────────────────────────
# Stage 1: Extrair FFmpeg do datarhei/base (Alpine 3.16 com FFmpeg 5.1.3)
# ──────────────────────────────────────────────────────────────────────────────
FROM datarhei/base:alpine-ffmpeg-latest AS ffmpeg-extract
# Os binários estão em /usr/local/bin/ffmpeg e /usr/local/bin/ffprobe
# (ou em /usr/bin — verificar no container)

# ──────────────────────────────────────────────────────────────────────────────
# Stage 2: Compilar TSDuck no Alpine 3.19 (OpenSSL 3 — compatível com v3.43)
# ──────────────────────────────────────────────────────────────────────────────
FROM alpine:3.19 AS tsduck-builder

RUN apk add --no-cache \
        bash python3 git cmake make g++ musl-dev \
        linux-headers curl-dev openssl-dev zlib-dev readline-dev

RUN git clone --depth=1 --branch v3.43-4549 \
        https://github.com/tsduck/tsduck.git /src/tsduck

WORKDIR /src/tsduck

# NOPCSC: sem smartcard | NOSRT/NORIST: sem SRT/RIST (não precisamos)
# NOEDITLINE: sem readline interativo | NODOC: sem asciidoctor HTML
RUN make -j$(nproc) \
        NOPCSC=1 NODTAPI=1 NOEAGLE=1 NOSRT=1 NORIST=1 NOHIDES=1 NOVATEK=1 NOEDITLINE=1 && \
    make install \
        NOPCSC=1 NODTAPI=1 NOEAGLE=1 NOSRT=1 NORIST=1 NOHIDES=1 NOVATEK=1 NOEDITLINE=1 NODOC=1 && \
    strip /usr/bin/tsp 2>/dev/null || true && \
    /usr/bin/tsp --version 2>&1 && \
    echo "TSDuck builder OK"

# ──────────────────────────────────────────────────────────────────────────────
# Stage Final: Alpine 3.19 runtime + FFmpeg + TSDuck
# ──────────────────────────────────────────────────────────────────────────────
FROM alpine:3.19

# Runtime deps para FFmpeg e TSDuck
RUN apk add --no-cache \
        ca-certificates tzdata \
        # TSDuck runtime deps
        libssl3 libcrypto3 curl libstdc++ libgcc readline \
        # FFmpeg runtime deps
        libgomp musl alsa-lib

# FFmpeg binário do datarhei/base (apenas ffmpeg — ffprobe não incluído nesta build)
COPY --from=ffmpeg-extract /usr/bin/ffmpeg  /usr/local/bin/ffmpeg

# TSDuck binários (compilados no Alpine 3.19 — mesmo musl/OpenSSL)
COPY --from=tsduck-builder /usr/bin/tsp          /usr/local/bin/tsp
COPY --from=tsduck-builder /usr/lib/libtsduck.so /usr/local/lib/libtsduck.so
COPY --from=tsduck-builder /usr/lib/libtscore.so /usr/local/lib/libtscore.so

RUN ldconfig /usr/local/lib 2>/dev/null || true && \
    /usr/local/bin/tsp --version 2>&1 && \
    /usr/local/bin/ffmpeg -version 2>&1 | head -1 && \
    echo "moovecast-base OK"

LABEL org.opencontainers.image.title="moovecast-base" \
      org.opencontainers.image.description="Moovecast base: Alpine 3.19 + FFmpeg 5.1.3 (datarhei) + TSDuck 3.43 (EIT injection)" \
      org.opencontainers.image.vendor="Moovesys" \
      org.opencontainers.image.version="1.0.0"
