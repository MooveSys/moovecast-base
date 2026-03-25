# moovecast-base

Imagem base para o **Moovecast Streaming Server** — combina `datarhei/base:alpine-ffmpeg` com o **TSDuck** pré-compilado nativamente para musl/Alpine.

## Para quê serve

O [TSDuck](https://tsduck.io/) (`tsp`) é usado para injetar tabelas **EIT (Electronic Information Table)** em streams UDP, entregando o **Guia de Programação** (EPG) para moduladores **ISDB-T** físicos (ex: Dexing).

## Imagem publicada

```
ghcr.io/moovesys/moovecast-base:latest
```

## Uso no Moovecast

```dockerfile
FROM ghcr.io/moovesys/moovecast-base:latest
# ... resto do Dockerfile do Moovecast
```

## Build local

Para rebuild da imagem base (ex: nova versão do TSDuck):

```bash
# 1. Compilar TSDuck no Alpine e gerar dist/
bash build-tsduck.sh

# 2. Build da imagem
docker build -t ghcr.io/moovesys/moovecast-base:latest .

# 3. Teste
docker run --rm ghcr.io/moovesys/moovecast-base:latest tsp --version

# 4. Push (precisa docker login ghcr.io)
docker push ghcr.io/moovesys/moovecast-base:latest
```

## TSDuck compilado com

```makefile
NOPCSC=1 NODTAPI=1 NOEAGLE=1 NOSRT=1 NORIST=1 NOHIDES=1 NOVATEK=1 NOEDITLINE=1 NODOC=1
```

Desativados: smartcard (PCSC), DTT DTVKit (DTAPI), Eagle MIS, SRT, RIST, HiDes, Vatek, line editor, HTML docs.
Ativos: UDP/IP, MPEG-TS, EIT/EPG, tables (PAT/PMT/SDT/NIT/EIT), ISDB-T.

## TSDuck versão

`v3.43-4549` (Jan 2024)
