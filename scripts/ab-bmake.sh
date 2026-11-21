#!/usr/bin/env bash
# ab-bmake.sh OLD_DEB NEW_DEB [ROUNDS]
# 比较真实 deb 中 meta2deps.py 的“成功启动次数/秒”；新版必须全部成功。
set -euo pipefail
OLD_DEB="${1:?old deb required}"; NEW_DEB="${2:?new deb required}"; ROUNDS="${3:-3}"
ROOT=/home/houge/build
N="${AB_EXECS:-200}"
[[ "$ROUNDS" =~ ^[1-9][0-9]*$ && "$N" =~ ^[1-9][0-9]*$ ]]
OLD_DEB="$(readlink -f "$OLD_DEB")"; NEW_DEB="$(readlink -f "$NEW_DEB")"
[[ -f "$OLD_DEB" && -f "$NEW_DEB" && "$OLD_DEB" != "$NEW_DEB" ]]
T="$(mktemp -d /tmp/ab-bmake.XXXXXX)"
mkdir -p "$T/old" "$T/new" "$ROOT/reports"
dpkg-deb -x "$OLD_DEB" "$T/old"; dpkg-deb -x "$NEW_DEB" "$T/new"
OLD_VER="$(dpkg-deb -f "$OLD_DEB" Version)"; NEW_VER="$(dpkg-deb -f "$NEW_DEB" Version)"
[[ "$(dpkg-deb -f "$OLD_DEB" Package)" == bmake ]]
[[ "$(dpkg-deb -f "$NEW_DEB" Package)" == bmake ]]
OLD_BIN="$T/old/usr/share/mk/meta2deps.py"; NEW_BIN="$T/new/usr/share/mk/meta2deps.py"
[[ -x "$OLD_BIN" && -x "$NEW_BIN" ]]
set +e
env -i PATH=/usr/bin:/bin "$OLD_BIN" </dev/null >"$T/old-once.out" 2>&1
OLD_RC=$?
set -e
env -i PATH=/usr/bin:/bin "$NEW_BIN" </dev/null >"$T/new-once.out" 2>&1
NEW_RC=$?
[[ $NEW_RC -eq 0 ]]
: >"$T/results.csv"
run_side() {
  local side="$1" round="$2" bin start end successes=0 i
  [[ "$side" == old ]] && bin="$OLD_BIN" || bin="$NEW_BIN"
  start="$(date +%s%N)"
  for ((i=1;i<=N;i++)); do
    if env -i PATH=/usr/bin:/bin "$bin" </dev/null >/dev/null 2>&1; then successes=$((successes+1)); fi
  done
  end="$(date +%s%N)"
  if [[ "$side" == new ]]; then [[ $successes -eq $N ]]; fi
  python3 - "$side" "$round" "$successes" "$N" "$start" "$end" >>"$T/results.csv" <<'PY'
import sys
side,r,ok,n,start,end=sys.argv[1:]
seconds=(int(end)-int(start))/1e9
assert seconds>0
print(f'{side},{r},{ok},{n},{seconds:.6f},{int(ok)/seconds:.2f}')
PY
}
for round in $(seq 1 "$ROUNDS"); do
  if ((round%2)); then order=(old new); else order=(new old); fi
  for side in "${order[@]}"; do run_side "$side" "$round"; done
done
python3 - "$T/results.csv" "$OLD_VER" "$NEW_VER" "$ROUNDS" "$N" "$OLD_RC" "$NEW_RC" "$ROOT/reports/ab-bmake.md" <<'PY'
import csv,statistics,sys
p,old,new,rounds,n,oldrc,newrc,out=sys.argv[1:]
rows=list(csv.DictReader(open(p),fieldnames=['side','round','successes','attempts','seconds','rate']))
vals={s:[float(r['rate']) for r in rows if r['side']==s] for s in ('old','new')}
counts={s:[int(r['successes']) for r in rows if r['side']==s] for s in ('old','new')}
assert len(vals['old'])==len(vals['new'])==int(rounds)
assert counts['new']==[int(n)]*int(rounds),counts
om=statistics.median(vals['old']); nm=statistics.median(vals['new'])
accepted=nm>om*1.05
speed='∞ (0 → positive)' if om==0 and nm>0 else (f'{nm/om:.3f}×' if om else 'undefined')
lines=['# bmake original/repaired A/B','',f'- Old: {old}',f'- New: {new}',
 f'- Direct no-argument launch: old rc={oldrc}; new rc={newrc}',
 f'- Attempts per side/round: {n}; rounds: {rounds}',
 '- Metric: successful `meta2deps.py` launches/s under identical `env -i PATH=/usr/bin:/bin`; new must succeed every time.','',
 '| Round | Old success | New success | Old launches/s | New launches/s |','| --- | ---: | ---: | ---: | ---: |']
for i in range(int(rounds)): lines.append(f'| {i+1} | {counts["old"][i]}/{n} | {counts["new"][i]}/{n} | {vals["old"][i]:.2f} | {vals["new"][i]:.2f} |')
lines += ['',f'Median: **{om:.2f} → {nm:.2f} successful launches/s**; speedup **{speed}**.',
 f'Decision: **{"ACCEPT" if accepted else "REJECT"}** (new median must exceed old by >1.05×).','']
text='\n'.join(lines); open(out,'w').write(text); print(text)
raise SystemExit(0 if accepted else 1)
PY
