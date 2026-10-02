#!/usr/bin/env bash
# Build one binary:          ./build.sh <wg|lowmem> <mips|mipsle|armv7|arm64|amd64>
# Source archive (GPL):      ./build.sh source
set -euo pipefail

VERSION=1.14.2
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/work/sing-box-$VERSION"
DIST="$ROOT/dist"
mkdir -p "$ROOT/work" "$DIST"

# 1. Download the v1.14.2 source and apply the patch
if [ ! -d "$SRC" ]; then
  curl -fsSL "https://github.com/SagerNet/sing-box/archive/refs/tags/v$VERSION.tar.gz" | tar xz -C "$ROOT/work"
  cp "$ROOT/patch/include/registry.go" "$SRC/include/registry.go"
  cp -r "$ROOT/patch/cmd/lite" "$SRC/cmd/lite"
fi

if [ "${1:-}" = "source" ]; then
  tar czf "$DIST/slim-proxy-$VERSION-source.tar.gz" -C "$ROOT/work" "sing-box-$VERSION"
  exit 0
fi

VARIANT="${1:?specify a variant: wg or lowmem}"
ARCH="${2:?specify an arch: mips, mipsle, armv7, arm64 or amd64}"

# 2. Architecture
case "$ARCH" in
  mips)   export GOARCH=mips   GOMIPS=softfloat ;;
  mipsle) export GOARCH=mipsle GOMIPS=softfloat ;;
  armv7)  export GOARCH=arm    GOARM=7 ;;
  arm64)  export GOARCH=arm64 ;;
  amd64)  export GOARCH=amd64 ;;
  *) echo "unknown arch: $ARCH"; exit 1 ;;
esac

# 3. Variant
case "$VARIANT" in
  wg)     TAGS="with_gvisor,with_wireguard" ;;  # with built-in WireGuard (userspace)
  lowmem) TAGS="with_low_memory" ;;             # no WireGuard, minimal memory
  *) echo "unknown variant: $VARIANT"; exit 1 ;;
esac
TAGS="$TAGS,badlinkname,tfogo_checklinkname0"

# 4. Build (static binary, no libc)
export GOOS=linux CGO_ENABLED=0
OUT="$DIST/slim-proxy-$VERSION-$VARIANT-linux-$ARCH"
cd "$SRC"
go build -trimpath \
  -ldflags "$(cat release/LDFLAGS) -s -w -buildid= -X github.com/sagernet/sing-box/constant.Version=$VERSION" \
  -tags "$TAGS" -o "$OUT" ./cmd/lite
( cd "$DIST" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
ls -l "$OUT"
