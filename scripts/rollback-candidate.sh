#!/usr/bin/env bash
# rollback-candidate.sh PKG OLD_VER OLD_REL NEW_VER NEW_REL
# A/B/build rejection cleanup: restore the accepted installed deb, then remove
# only the rejected main/debug artifacts. Idempotent; never deletes before the
# accepted package is verified installed.
set -euo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
HOST="${PUBLISH_HOST:-houge@10.147.17.139}"
INCOMING="${PUBLISH_INCOMING:-/home/houge/incoming}"
PKG="${1:?package required}"; OLD_VER="${2:?old version required}"; OLD_REL="${3:?old rel required}"; NEW_VER="${4:?new version required}"; NEW_REL="${5:?new rel required}"
[[ "$PKG" =~ ^[a-z0-9][a-z0-9+.-]+$ ]]
[[ "$OLD_VER" =~ ^[A-Za-z0-9.+:~_-]+$ && "$NEW_VER" =~ ^[A-Za-z0-9.+:~_-]+$ ]]
[[ "$OLD_REL" =~ ^[0-9]+$ && "$NEW_REL" =~ ^[0-9]+$ ]]
mkdir -p "$ROOT/debs"

fetch_old() {
  local pkg="$1" base arch remote found
  for arch in loongarch64 all noarch; do
    found="$ROOT/debs/${pkg}_${OLD_VER}-${OLD_REL}_${arch}.deb"
    if [[ -f "$found" ]]; then printf '%s\n' "$found"; return 0; fi
  done
  remote="$(ssh -o BatchMode=yes "$HOST" python3 - "$INCOMING" "$PKG" "$OLD_VER" "$OLD_REL" "$pkg" <<'PY'
from pathlib import Path
import sys
root,pkg,ver,rel,binary=sys.argv[1:]
names=[f'{binary}_{ver}-{rel}_{a}.deb' for a in ('loongarch64','all','noarch')]
for name in names:
 p=Path(root)/name
 if p.is_file(): print(p); raise SystemExit(0)
for name in names:
 hits=sorted(p for p in Path(root).glob(f'*/{name}') if p.is_file())
 if hits: print(hits[0]); raise SystemExit(0)
raise SystemExit(1)
PY
)" || return 1
  base="$(basename "$remote")"
  scp -q "$HOST:$remote" "$ROOT/debs/$base"
  found="$ROOT/debs/$base"
  [[ "$(dpkg-deb -f "$found" Package)" == "$pkg" ]]
  [[ "$(dpkg-deb -f "$found" Version)" == "$OLD_VER-$OLD_REL" ]]
  printf '%s\n' "$found"
}

installed() { dpkg-query -W -f='${Version}' "$1" 2>/dev/null || true; }
MAIN_BEFORE="$(installed "$PKG")"
[[ -z "$MAIN_BEFORE" || "$MAIN_BEFORE" == "$OLD_VER-$OLD_REL" || "$MAIN_BEFORE" == "$NEW_VER-$NEW_REL" ]] || {
  echo "rollback refused: $PKG installed $MAIN_BEFORE is neither old nor rejected version" >&2; exit 1; }
OLD_MAIN="$(fetch_old "$PKG" main)"
DBG="$PKG-dbg"; DBG_BEFORE="$(installed "$DBG")"; OLD_DBG=""
if [[ "$DBG_BEFORE" == "$NEW_VER-$NEW_REL" ]]; then OLD_DBG="$(fetch_old "$DBG" debug || true)"; fi
if [[ "$MAIN_BEFORE" == "$NEW_VER-$NEW_REL" || "$DBG_BEFORE" == "$NEW_VER-$NEW_REL" ]]; then
  install=("$OLD_MAIN"); [[ -z "$OLD_DBG" ]] || install+=("$OLD_DBG")
  sudo -n apt-get install -y --allow-downgrades "${install[@]}"
  if [[ "$DBG_BEFORE" == "$NEW_VER-$NEW_REL" && -z "$OLD_DBG" && -n "$(installed "$DBG")" ]]; then sudo -n apt-get remove -y "$DBG"; fi
fi
[[ -z "$MAIN_BEFORE" || "$(installed "$PKG")" == "$OLD_VER-$OLD_REL" ]]
DBG_AFTER="$(installed "$DBG")"
[[ -z "$DBG_AFTER" || "$DBG_AFTER" == "$OLD_VER-$OLD_REL" ]]
python3 - "$ROOT/debs" "$PKG" "$NEW_VER" "$NEW_REL" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]).resolve(); pkg,ver,rel=sys.argv[2:]
for binary in (pkg,pkg+'-dbg'):
 for p in root.glob(f'{binary}_{ver}-{rel}_*.deb'):
  rp=p.resolve(); assert rp.parent==root and rp.is_file(),rp
  print('removed rejected artifact:',rp.name); rp.unlink()
PY
printf 'rollback PASS: %s installed=%s; rejected=%s-%s artifacts removed\n' "$PKG" "$(installed "$PKG")" "$NEW_VER" "$NEW_REL"
