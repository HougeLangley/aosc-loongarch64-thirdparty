#!/usr/bin/env bash
# ab-valkey.sh OLD_VER NEW_VER [ROUNDS]
# 直接比较两个已构建 deb 的 valkey-server；不在 A/B 内改配方或重建变体。
set -euo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
OLD="${1:?old version required}"
NEW="${2:?new version required}"
ROUNDS="${3:-${AB_ROUNDS:-3}}"
REQS="${AB_REQS:-200000}"
CLIENTS="${AB_CLIENTS:-50}"
OLD_DEB="$ROOT/debs/valkey_${OLD}-1_loongarch64.deb"
NEW_DEB="$ROOT/debs/valkey_${NEW}-1_loongarch64.deb"
[[ -f "$OLD_DEB" && -f "$NEW_DEB" ]]
exec 8>"${AB_VALKEY_LOCK:-/tmp/ab-valkey.lock}"
flock -n 8 || { echo 'another valkey A/B is running' >&2; exit 2; }
T="$(mktemp -d /tmp/valkey-version-ab.XXXXXX)"
OLD_PID='' NEW_PID=''
cleanup() {
  [[ -n "$OLD_PID" ]] && "$T/old/usr/bin/valkey-cli" -p 7801 shutdown nosave >/dev/null 2>&1 || true
  [[ -n "$NEW_PID" ]] && "$T/new/usr/bin/valkey-cli" -p 7802 shutdown nosave >/dev/null 2>&1 || true
  for pid in "$OLD_PID" "$NEW_PID"; do
    [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  rm -rf -- "$T"
}
trap cleanup EXIT

dpkg-deb -x "$OLD_DEB" "$T/old"
dpkg-deb -x "$NEW_DEB" "$T/new"
for side in old new; do
  expected="$OLD"; [[ "$side" == new ]] && expected="$NEW"
  "$T/$side/usr/bin/valkey-server" --version | grep -F "v=$expected" >/dev/null
  "$T/$side/usr/bin/valkey-benchmark" --version | grep -Fx "valkey-benchmark $expected" >/dev/null
done

start_server() {
  local side="$1" port="$2"
  "$T/$side/usr/bin/valkey-server" --port "$port" --bind 127.0.0.1 \
    --save '' --appendonly no --daemonize no --loglevel warning --dir "$T/$side" \
    >"$T/$side-server.log" 2>&1 &
  SERVER_PID=$!
}
start_server old 7801
OLD_PID="$SERVER_PID"
start_server new 7802
NEW_PID="$SERVER_PID"
for side in old new; do
  port=7801; pid="$OLD_PID"; [[ "$side" == new ]] && { port=7802; pid="$NEW_PID"; }
  ready=0
  for _ in $(seq 1 100); do
    if [[ "$("$T/$side/usr/bin/valkey-cli" -p "$port" ping 2>/dev/null)" == PONG ]]; then ready=1; break; fi
    kill -0 "$pid" 2>/dev/null || { cat "$T/$side-server.log" >&2; exit 1; }
    sleep 0.1
  done
  [[ $ready -eq 1 ]] || { cat "$T/$side-server.log" >&2; exit 1; }
  [[ "$("$T/$side/usr/bin/valkey-cli" -p "$port" set ab-payload "$side-value")" == OK ]]
  [[ "$("$T/$side/usr/bin/valkey-cli" -p "$port" get ab-payload)" == "$side-value" ]]
  "$T/$side/usr/bin/valkey-benchmark" -p "$port" -n 5000 -c "$CLIENTS" -t set,get -q >/dev/null
done

printf 'round,side,ops_per_second\n' > "$T/results.csv"
measure() {
  local round="$1" side="$2" port="$3" out ops
  out="$("$T/$side/usr/bin/valkey-benchmark" -p "$port" -n "$REQS" -c "$CLIENTS" -t set,get -q 2>/dev/null)"
  ops="$(python3 -c 'import re,sys; v=[float(x) for x in re.findall(r"([0-9]+(?:\.[0-9]+)?) requests per second",sys.stdin.read())]; assert len(v)==2,v; print(sum(v)/len(v))' <<<"$out")"
  printf '%s,%s,%s\n' "$round" "$side" "$ops" >> "$T/results.csv"
}
for round in $(seq 1 "$ROUNDS"); do
  if (( round % 2 )); then
    measure "$round" old 7801
    measure "$round" new 7802
  else
    measure "$round" new 7802
    measure "$round" old 7801
  fi
done

python3 - "$T/results.csv" "$OLD" "$NEW" "$ROUNDS" "$REQS" "$CLIENTS" \
  "$ROOT/logs/valkey-version.ab.json" "$ROOT/reports/ab-valkey.md" <<'PY'
import csv,json,statistics,sys
from collections import defaultdict
from pathlib import Path
path,old,new,rounds,reqs,clients,json_out,report=sys.argv[1:]
rounds=int(rounds)
data=defaultdict(dict)
with open(path,newline='') as f:
    for row in csv.DictReader(f): data[row['side']][int(row['round'])]=float(row['ops_per_second'])
assert set(data)=={'old','new'}
for side in ('old','new'): assert set(data[side])==set(range(1,rounds+1))
old_med=statistics.median(data['old'].values()); new_med=statistics.median(data['new'].values())
result={'old':old,'new':new,'rounds':rounds,'requests_per_test':int(reqs),'clients':int(clients),
        'old_ops_per_second':data['old'],'new_ops_per_second':data['new'],
        'old_median_ops_per_second':old_med,'new_median_ops_per_second':new_med,
        'speedup':new_med/old_med,'minimum_speedup':1.05,'accepted':new_med>old_med*1.05,
        'set_get_verified':True,'versions_match':True}
Path(json_out).write_text(json.dumps(result,indent=2)+'\n')
lines=['# valkey version A/B','',f'- Old: {old}',f'- New: {new}',
       f'- Requests per SET/GET test: {reqs}; clients: {clients}; rounds: {rounds}',
       '', '| Round | Old ops/s | New ops/s |','| --- | ---: | ---: |']
for r in range(1,rounds+1): lines.append(f"| {r} | {data['old'][r]:.0f} | {data['new'][r]:.0f} |")
lines += ['',f'Median: **{old_med:.0f} → {new_med:.0f} ops/s**; speedup **{new_med/old_med:.3f}×**.',
          f"Decision: **{'ACCEPT' if result['accepted'] else 'REJECT'}** (requires >1.05×).",'']
Path(report).write_text('\n'.join(lines))
print('\n'.join(lines))
raise SystemExit(0 if result['accepted'] else 1)
PY
