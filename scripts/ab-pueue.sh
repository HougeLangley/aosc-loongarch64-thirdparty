#!/usr/bin/env bash
# ab-pueue.sh OLD_VER NEW_VER [ROUNDS]
# 两个独立 daemon 的真实入队 + /bin/true 执行吞吐；严格校验全部任务成功。
set -euo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
OLD="${1:?old version required}"
NEW="${2:?new version required}"
ROUNDS="${3:-${AB_ROUNDS:-3}}"
TASKS="${AB_TASKS:-100}"
PARALLEL="${AB_PARALLEL:-8}"
OLD_DEB="$ROOT/debs/pueue_${OLD}-1_loongarch64.deb"
NEW_DEB="$ROOT/debs/pueue_${NEW}-1_loongarch64.deb"
[[ -f "$OLD_DEB" && -f "$NEW_DEB" ]]
exec 8>"${AB_PUEUE_LOCK:-/tmp/ab-pueue.lock}"
flock -n 8 || { echo 'another pueue A/B is running' >&2; exit 2; }
T="$(mktemp -d /tmp/pueue-version-ab.XXXXXX)"
OLD_PID='' NEW_PID=''
client() {
  local side="$1"; shift
  env HOME="$T/$side/home" XDG_CONFIG_HOME="$T/$side/config" \
    XDG_RUNTIME_DIR="$T/$side/runtime" XDG_DATA_HOME="$T/$side/data" \
    XDG_STATE_HOME="$T/$side/state" XDG_CACHE_HOME="$T/$side/cache" \
    "$T/$side/usr/bin/pueue" "$@"
}
shutdown_side() {
  local side="$1"
  [[ -x "$T/$side/usr/bin/pueue" ]] && client "$side" shutdown >/dev/null 2>&1 || true
}
cleanup() {
  shutdown_side old
  shutdown_side new
  for pid in "$OLD_PID" "$NEW_PID"; do [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true; done
  wait 2>/dev/null || true
  rm -rf -- "$T"
}
trap cleanup EXIT

dpkg-deb -x "$OLD_DEB" "$T/old"
dpkg-deb -x "$NEW_DEB" "$T/new"
for side in old new; do
  expected="$OLD"; [[ "$side" == new ]] && expected="$NEW"
  "$T/$side/usr/bin/pueue" --version | grep -Fx "pueue $expected" >/dev/null
  "$T/$side/usr/bin/pueued" --version | grep -Fx "pueued $expected" >/dev/null
  mkdir -p "$T/$side"/{home,config,runtime,data,state,cache}
done

start_daemon() {
  local side="$1"
  env HOME="$T/$side/home" XDG_CONFIG_HOME="$T/$side/config" \
    XDG_RUNTIME_DIR="$T/$side/runtime" XDG_DATA_HOME="$T/$side/data" \
    XDG_STATE_HOME="$T/$side/state" XDG_CACHE_HOME="$T/$side/cache" \
    "$T/$side/usr/bin/pueued" >"$T/$side-daemon.log" 2>&1 &
  DAEMON_PID=$!
}
start_daemon old; OLD_PID="$DAEMON_PID"
start_daemon new; NEW_PID="$DAEMON_PID"
for side in old new; do
  pid="$OLD_PID"; [[ "$side" == new ]] && pid="$NEW_PID"
  ready=0
  for _ in $(seq 1 100); do
    if client "$side" status --json >/dev/null 2>&1; then ready=1; break; fi
    kill -0 "$pid" 2>/dev/null || { cat "$T/$side-daemon.log" >&2; exit 1; }
    sleep 0.1
  done
  [[ $ready -eq 1 ]] || { cat "$T/$side-daemon.log" >&2; exit 1; }
  client "$side" parallel "$PARALLEL" >/dev/null
  for _ in $(seq 1 16); do client "$side" add --print-task-id -- /bin/true >/dev/null; done
  client "$side" wait --quiet
  client "$side" clean >/dev/null
done

printf 'round,side,tasks_per_second\n' > "$T/results.csv"
measure() {
  local round="$1" side="$2" start end ops i
  start="$(date +%s%N)"
  for i in $(seq 1 "$TASKS"); do client "$side" add --print-task-id -- /bin/true >/dev/null; done
  client "$side" wait --quiet
  end="$(date +%s%N)"
  ops="$(python3 -c 'import sys; n,s,e=map(float,sys.argv[1:]); assert e>s; print(n*1e9/(e-s))' "$TASKS" "$start" "$end")"
  client "$side" status --json > "$T/$side-status-$round.json"
  python3 - "$T/$side-status-$round.json" "$TASKS" <<'PY'
import json,sys
p,n=sys.argv[1],int(sys.argv[2])
data=json.load(open(p)); tasks=data.get('tasks')
assert isinstance(tasks,dict) and len(tasks)==n,(type(tasks),len(tasks) if isinstance(tasks,dict) else None,n)
for task in tasks.values():
    status=task.get('status')
    ok=status=='Success' or (isinstance(status,dict) and (
        'Success' in status or status.get('Done',{}).get('result')=='Success'
    ))
    assert ok,(task.get('id'),status)
PY
  client "$side" clean >/dev/null
  printf '%s,%s,%s\n' "$round" "$side" "$ops" >> "$T/results.csv"
}
for round in $(seq 1 "$ROUNDS"); do
  if (( round % 2 )); then measure "$round" old; measure "$round" new
  else measure "$round" new; measure "$round" old; fi
done

python3 - "$T/results.csv" "$OLD" "$NEW" "$ROUNDS" "$TASKS" "$PARALLEL" \
  "$ROOT/logs/pueue-version.ab.json" "$ROOT/reports/ab-pueue.md" <<'PY'
import csv,json,statistics,sys
from collections import defaultdict
from pathlib import Path
path,old,new,rounds,tasks,parallel,json_out,report=sys.argv[1:]
rounds=int(rounds)
data=defaultdict(dict)
with open(path,newline='') as f:
    for row in csv.DictReader(f): data[row['side']][int(row['round'])]=float(row['tasks_per_second'])
assert set(data)=={'old','new'}
for side in ('old','new'): assert set(data[side])==set(range(1,rounds+1))
old_med=statistics.median(data['old'].values()); new_med=statistics.median(data['new'].values())
result={'old':old,'new':new,'rounds':rounds,'tasks_per_round':int(tasks),'parallel_tasks':int(parallel),
        'old_tasks_per_second':data['old'],'new_tasks_per_second':data['new'],
        'old_median_tasks_per_second':old_med,'new_median_tasks_per_second':new_med,
        'speedup':new_med/old_med,'minimum_speedup':1.05,'accepted':new_med>old_med*1.05,
        'all_tasks_successful':True,'versions_match':True}
Path(json_out).write_text(json.dumps(result,indent=2)+'\n')
lines=['# pueue version A/B','',f'- Old: {old}',f'- New: {new}',
       f'- Tasks per round: {tasks}; parallel workers: {parallel}; rounds: {rounds}',
       '- Workload: real client enqueue + daemon execution of `/bin/true`; every task checked `Success`.',
       '', '| Round | Old tasks/s | New tasks/s |','| --- | ---: | ---: |']
for r in range(1,rounds+1): lines.append(f"| {r} | {data['old'][r]:.2f} | {data['new'][r]:.2f} |")
lines += ['',f'Median: **{old_med:.2f} → {new_med:.2f} tasks/s**; speedup **{new_med/old_med:.3f}×**.',
          f"Decision: **{'ACCEPT' if result['accepted'] else 'REJECT'}** (requires >1.05×).",'']
Path(report).write_text('\n'.join(lines))
print('\n'.join(lines))
raise SystemExit(0 if result['accepted'] else 1)
PY
