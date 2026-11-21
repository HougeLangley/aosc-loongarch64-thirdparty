#!/usr/bin/env bash
# Shared real-data JSON filter A/B. Invoke as ab-fx.sh or ab-jaq.sh.
# Usage: ab-fx.sh OLD_VER NEW_VER [ROUNDS]
# AB_OLD_DEB/AB_NEW_DEB optionally select exact original ACBS artifacts.
set -euo pipefail
TOOL="$(basename "$0")"; TOOL="${TOOL#ab-}"; TOOL="${TOOL%.sh}"
[[ "$TOOL" == fx || "$TOOL" == jaq ]]
OLD_VER="${1:?old version}"; NEW_VER="${2:?new version}"; ROUNDS="${3:-3}"
ROOT="${BUILD_ROOT:-$HOME/build}"; RECORDS="${AB_RECORDS:-30000}"
[[ "$ROUNDS" =~ ^[1-9][0-9]*$ && "$RECORDS" =~ ^[1-9][0-9]*$ ]]
find_deb() {
  local ver="$1" override="$2" p; local -a hits=()
  if [[ -n "$override" ]]; then [[ -f "$override" ]] || return 1; readlink -f "$override"; return; fi
  shopt -s nullglob
  hits=("$ROOT/debs/${TOOL}_${ver}-"*_loongarch64.deb "$ROOT/debs/${TOOL}_${ver}-"*_all.deb)
  shopt -u nullglob
  [[ ${#hits[@]} -eq 1 ]] || { echo "expected one $TOOL $ver deb, got ${#hits[@]}" >&2; return 1; }
  readlink -f "${hits[0]}"
}
OLD_DEB="$(find_deb "$OLD_VER" "${AB_OLD_DEB:-}")"; NEW_DEB="$(find_deb "$NEW_VER" "${AB_NEW_DEB:-}")"
[[ "$OLD_DEB" != "$NEW_DEB" ]]
T="$(mktemp -d "/tmp/ab-$TOOL.XXXXXX")"; mkdir -p "$T/old" "$T/new" "$T/home" "$ROOT/reports"
dpkg-deb -x "$OLD_DEB" "$T/old"; dpkg-deb -x "$NEW_DEB" "$T/new"
OLD_PKGVER="$(dpkg-deb -f "$OLD_DEB" Version)"; NEW_PKGVER="$(dpkg-deb -f "$NEW_DEB" Version)"
[[ "$(dpkg-deb -f "$OLD_DEB" Package)" == "$TOOL" && "$(dpkg-deb -f "$NEW_DEB" Package)" == "$TOOL" ]]
OLD_BIN="$T/old/usr/bin/$TOOL"; NEW_BIN="$T/new/usr/bin/$TOOL"; [[ -x "$OLD_BIN" && -x "$NEW_BIN" ]]
INPUT="$T/input.json"
python3 - "$INPUT" "$RECORDS" <<'PY'
import json,sys
p,n=sys.argv[1:]; n=int(n)
with open(p,'w') as f:
 json.dump({'items':[{'id':i,'group':i%32,'value':(i*37)%1000,'active':i%3==0,'name':f'record-{i:06d}'} for i in range(n)]},f,separators=(',',':'))
PY
run_capture() {
  local bin="$1" out="$2"
  if [[ "$TOOL" == fx ]]; then
    (cd "$T" && env -i PATH=/usr/bin:/bin HOME="$T/home" NO_COLOR=1 TERM=dumb "$bin" --no-tui "$INPUT" .items >"$out")
  else
    (cd "$T" && env -i PATH=/usr/bin:/bin HOME="$T/home" NO_COLOR=1 TERM=dumb "$bin" -c '.items | map(select(.active and .group < 8)) | map({id,value,name})' "$INPUT" >"$out")
  fi
}
run_capture "$OLD_BIN" "$T/old.json"; run_capture "$NEW_BIN" "$T/new.json"
python3 - "$TOOL" "$INPUT" "$T/old.json" "$T/new.json" "$T/semantic.sha256" <<'PY'
import hashlib,json,sys
tool,source,oldp,newp,hashp=sys.argv[1:]
items=json.load(open(source))['items']; old=json.load(open(oldp)); new=json.load(open(newp))
if tool=='fx': expected=items
else: expected=[{k:o[k] for k in ('id','value','name')} for o in items if o['active'] and o['group']<8]
assert old==new==expected,(tool,len(old),len(new),len(expected))
blob=json.dumps(new,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()
open(hashp,'w').write(hashlib.sha256(blob).hexdigest())
PY
SEM_SHA="$(cat "$T/semantic.sha256")"
: >"$T/results.csv"
run_timed() {
  local side="$1" round="$2" bin start end
  [[ "$side" == old ]] && bin="$OLD_BIN" || bin="$NEW_BIN"
  start="$(date +%s%N)"
  if [[ "$TOOL" == fx ]]; then
    (cd "$T" && env -i PATH=/usr/bin:/bin HOME="$T/home" NO_COLOR=1 TERM=dumb timeout 120 "$bin" --no-tui "$INPUT" .items >/dev/null)
  else
    (cd "$T" && env -i PATH=/usr/bin:/bin HOME="$T/home" NO_COLOR=1 TERM=dumb timeout 120 "$bin" -c '.items | map(select(.active and .group < 8)) | map({id,value,name})' "$INPUT" >/dev/null)
  fi
  end="$(date +%s%N)"
  python3 - "$side" "$round" "$start" "$end" "$RECORDS" >>"$T/results.csv" <<'PY'
import sys
side,r,start,end,n=sys.argv[1:]
seconds=(int(end)-int(start))/1e9
assert seconds>0
print(f'{side},{r},{seconds:.6f},{int(n)/seconds:.2f}')
PY
}
for round in $(seq 1 "$ROUNDS"); do
  if ((round%2)); then order=(old new); else order=(new old); fi
  for side in "${order[@]}"; do run_timed "$side" "$round"; done
done
python3 - "$T/results.csv" "$TOOL" "$OLD_PKGVER" "$NEW_PKGVER" "$ROUNDS" "$RECORDS" "$SEM_SHA" "$ROOT/reports/ab-$TOOL.md" <<'PY'
import csv,statistics,sys
p,tool,old,new,rounds,records,sem,out=sys.argv[1:]
rows=list(csv.DictReader(open(p),fieldnames=['side','round','seconds','rate']))
vals={s:[float(r['rate']) for r in rows if r['side']==s] for s in ('old','new')}
assert len(vals['old'])==len(vals['new'])==int(rounds)
om=statistics.median(vals['old']); nm=statistics.median(vals['new']); accepted=nm>om*1.05
lines=[f'# {tool} original/candidate real-data A/B','',f'- Old: {old}',f'- New: {new}',f'- Records per run: {records}; rounds: {rounds}',
 f'- Functional result: old/new outputs both equal the expected JSON; canonical SHA256 `{sem}`',
 '- Workload: fx materializes `.items`; jaq filters active/group and projects id/value/name. Timed output goes to /dev/null.','',
 '| Round | Old records/s | New records/s |','| --- | ---: | ---: |']
for i in range(int(rounds)): lines.append(f'| {i+1} | {vals["old"][i]:.2f} | {vals["new"][i]:.2f} |')
lines += ['',f'Median: **{om:.2f} → {nm:.2f} records/s**; speedup **{nm/om:.3f}×**.',f'Decision: **{"ACCEPT" if accepted else "REJECT"}** (new median must exceed old by >1.05×).','']
text='\n'.join(lines); open(out,'w').write(text); print(text)
raise SystemExit(0 if accepted else 1)
PY
