#!/usr/bin/env bash
# Сборка одного бинарника:   ./build.sh <wg|lowmem> <mips|mipsle|armv7|arm64|amd64>
# Архив исходников (GPL):     ./build.sh source
set -euo pipefail

VERSION=1.14.2
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/work/sing-box-$VERSION"
DIST="$ROOT/dist"
mkdir -p "$ROOT/work" "$DIST"

# 1. Скачать исходники v1.14.2 и наложить патч
if [ ! -d "$SRC" ]; then
  curl -fsSL "https://github.com/SagerNet/sing-box/archive/refs/tags/v$VERSION.tar.gz" | tar xz -C "$ROOT/work"
  cp "$ROOT/patch/include/registry.go" "$SRC/include/registry.go"
  cp -r "$ROOT/patch/cmd/lite" "$SRC/cmd/lite"
fi

if [ "${1:-}" = "source" ]; then
  tar czf "$DIST/slim-proxy-$VERSION-source.tar.gz" -C "$ROOT/work" "sing-box-$VERSION"
  exit 0
fi

VARIANT="${1:?укажите вариант: wg или lowmem}"
ARCH="${2:?укажите архитектуру: mips, mipsle, armv7, arm64 или amd64}"

# 2. Архитектура
case "$ARCH" in
  mips)   export GOARCH=mips   GOMIPS=softfloat ;;
  mipsle) export GOARCH=mipsle GOMIPS=softfloat ;;
  armv7)  export GOARCH=arm    GOARM=7 ;;
  arm64)  export GOARCH=arm64 ;;
  amd64)  export GOARCH=amd64 ;;
  *) echo "неизвестная архитектура: $ARCH"; exit 1 ;;
esac

# 3. Вариант
case "$VARIANT" in
  wg)     TAGS="with_gvisor,with_wireguard" ;;  # со встроенным WireGuard (userspace)
  lowmem) TAGS="with_low_memory" ;;             # без WireGuard, минимум памяти
  *) echo "неизвестный вариант: $VARIANT"; exit 1 ;;
esac
TAGS="$TAGS,badlinkname,tfogo_checklinkname0"

# 4. Сборка (статический бинарник, без libc)
export GOOS=linux CGO_ENABLED=0
OUT="$DIST/slim-proxy-$VERSION-$VARIANT-linux-$ARCH"
cd "$SRC"
go build -trimpath \
  -ldflags "$(cat release/LDFLAGS) -s -w -buildid= -X github.com/sagernet/sing-box/constant.Version=$VERSION" \
  -tags "$TAGS" -o "$OUT" ./cmd/lite
( cd "$DIST" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
ls -l "$OUT"
