#!/usr/bin/env bash
# wowtype-release-ready.sh VERSION [RECIPE_DIR]
# Git tag 可能早于 release 资产；只有资产及官方 SHA256SUMS 对齐才允许构建。
# 退出：0 就绪；1 清单/hash 与配方冲突（需改配方）；2 release/资产尚未就绪（下轮重试）。
set -uo pipefail
VER="${1:?version required}"
RECIPE="${2:-/home/houge/build/tree/aosc-loongarch64-thirdparty/packages/i18n/wowtype}"
BUILD="$RECIPE/autobuild/build"
[[ -f "$BUILD" ]] || { echo "missing wowtype build recipe: $BUILD" >&2; exit 1; }
DATA_VER="$(sed -n 's/^DATA_VER=//p' "$BUILD" | head -1)"
DATA_SHA="$(sed -n 's/^DATA_SHA=//p' "$BUILD" | head -1)"
[[ "$DATA_VER" =~ ^[0-9.]+$ && "$DATA_SHA" =~ ^[0-9a-f]{64}$ ]] || {
  echo 'invalid DATA_VER or DATA_SHA in wowtype recipe' >&2; exit 1;
}
ASSET="wowtype-data-rime-ice-${DATA_VER}.tar.gz"
BASE="${WOWTYPE_RELEASE_BASE:-https://github.com/Gloridust/WowType/releases/download}"
MANIFEST_URL="$BASE/v$VER/SHA256SUMS"
if ! MANIFEST="$(curl -fsSL --retry 2 --connect-timeout 10 --max-time 45 "$MANIFEST_URL")"; then
  echo "wowtype $VER release manifest not ready: $MANIFEST_URL" >&2
  exit 2
fi
ACTUAL="$(awk -v f="$ASSET" '$2 == f {print $1}' <<<"$MANIFEST")"
if [[ ! "$ACTUAL" =~ ^[0-9a-f]{64}$ ]]; then
  echo "wowtype $VER asset not ready in SHA256SUMS: $ASSET" >&2
  exit 2
fi
if [[ "$ACTUAL" != "$DATA_SHA" ]]; then
  echo "wowtype $VER data checksum changed: recipe=$DATA_SHA upstream=$ACTUAL" >&2
  exit 1
fi
printf 'wowtype %s data asset ready: %s sha256=%s\n' "$VER" "$ASSET" "$ACTUAL"
