#!/usr/bin/env bash
# ab-v2raya.sh OLD_VER NEW_VER [ROUNDS]
# 同机、同负载、交替轮次；经各自 v2raya_core 的 SOCKS 入站访问同一 HTTP 服务。
# 功能与版本一致性是前置门槛，严格 new median p95 < old median p95 才返回 0。
set -euo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
OLD="${1:?old version required}"
NEW="${2:?new version required}"
ROUNDS="${3:-${AB_ROUNDS:-5}}"
SAMPLES="${AB_V2RAYA_SAMPLES:-40}"
OLD_DEB="$ROOT/debs/v2raya_${OLD}-1_loongarch64.deb"
NEW_DEB="$ROOT/debs/v2raya_${NEW}-1_loongarch64.deb"
[[ -f "$OLD_DEB" && -f "$NEW_DEB" ]]
exec 8>"${AB_V2RAYA_LOCK:-/tmp/ab-v2raya.lock}"
flock -n 8 || { echo 'another v2raya A/B is running' >&2; exit 2; }
T="$(mktemp -d /tmp/v2raya-ab.XXXXXX)"
HTTP_PID='' OLD_PID='' NEW_PID=''
cleanup() {
  for pid in "$OLD_PID" "$NEW_PID" "$HTTP_PID"; do
    [[ -n "$pid" ]] && kill -TERM "$pid" 2>/dev/null || true
  done
  wait 2>/dev/null || true
  rm -rf -- "$T"
}
trap cleanup EXIT

dpkg-deb -x "$OLD_DEB" "$T/old"
dpkg-deb -x "$NEW_DEB" "$T/new"
for side in old new; do
  expected="${OLD}"; [[ "$side" == new ]] && expected="$NEW"
  main="$("$T/$side/usr/bin/v2raya" --version | awk 'NR==1{print $1}')"
  core="$("$T/$side/usr/bin/v2raya_core" --version | awk 'NR==1 && $1=="V2RAYA_CORE"{print $2}')"
  [[ "$main" == "$expected" && "$core" == "$expected" ]] || {
    echo "$side version mismatch: main=$main core=$core expected=$expected" >&2; exit 1;
  }
done

# 1 MiB 固定载荷，先逐位校验两个代理路径，再测延迟。
python3 - "$T/payload.bin" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_bytes(bytes(range(256)) * 4096)
PY
HTTP_PORT=28080
OLD_PORT=28180
NEW_PORT=28280
python3 -m http.server "$HTTP_PORT" --bind 127.0.0.1 --directory "$T" >"$T/http.log" 2>&1 &
HTTP_PID=$!
for _ in $(seq 1 50); do
  curl -fsS --noproxy '*' --max-time 1 "http://127.0.0.1:$HTTP_PORT/payload.bin" -o /dev/null && break
  sleep 0.1
done

start_core() {
  local side="$1" port="$2" conf="$T/$1.json"
  cat > "$conf" <<JSON
{
  "log": {"loglevel": "error"},
  "inbounds": [{"listen": "127.0.0.1", "port": $port, "protocol": "socks", "settings": {"auth": "noauth", "udp": false}}],
  "outbounds": [{"protocol": "freedom", "tag": "direct", "settings": {"domainStrategy": "UseIP"}}]
}
JSON
  "$T/$side/usr/bin/v2raya_core" run --config="$conf" >"$T/$side.log" 2>&1 &
  printf '%s' "$!"
}
OLD_PID="$(start_core old "$OLD_PORT")"
NEW_PID="$(start_core new "$NEW_PORT")"
for side in old new; do
  port="$OLD_PORT"; pid="$OLD_PID"
  [[ "$side" == new ]] && { port="$NEW_PORT"; pid="$NEW_PID"; }
  ready=0
  for _ in $(seq 1 100); do
    if curl -fsS --noproxy '*' --socks5-hostname "127.0.0.1:$port" --max-time 2 \
      "http://127.0.0.1:$HTTP_PORT/payload.bin" -o "$T/$side.received"; then ready=1; break; fi
    kill -0 "$pid" 2>/dev/null || { cat "$T/$side.log" >&2; exit 1; }
    sleep 0.1
  done
  [[ $ready -eq 1 ]] || { cat "$T/$side.log" >&2; exit 1; }
  cmp "$T/payload.bin" "$T/$side.received"
done

printf 'round,side,sample,seconds\n' > "$T/results.csv"
measure() {
  local round="$1" side="$2" port="$3"
  for sample in $(seq 1 "$SAMPLES"); do
    seconds="$(curl -fsS --noproxy '*' --socks5-hostname "127.0.0.1:$port" --max-time 10 \
      "http://127.0.0.1:$HTTP_PORT/payload.bin" -o /dev/null -w '%{time_total}')"
    printf '%s,%s,%s,%s\n' "$round" "$side" "$sample" "$seconds" >> "$T/results.csv"
  done
}
for round in $(seq 1 "$ROUNDS"); do
  if (( round % 2 )); then
    measure "$round" old "$OLD_PORT"
    measure "$round" new "$NEW_PORT"
  else
    measure "$round" new "$NEW_PORT"
    measure "$round" old "$OLD_PORT"
  fi
done

python3 - "$T/results.csv" "$OLD" "$NEW" "$ROUNDS" "$SAMPLES" "$ROOT/logs/v2raya.ab.json" <<'PY'
import csv,json,math,statistics,sys
from collections import defaultdict
path,old,new,rounds,samples,out=sys.argv[1:]
rounds,samples=int(rounds),int(samples)
data=defaultdict(lambda:defaultdict(list))
with open(path,newline='') as f:
    for row in csv.DictReader(f): data[row['side']][int(row['round'])].append(float(row['seconds']))
assert set(data)=={'old','new'},data.keys()
p95={}
for side in ('old','new'):
    assert set(data[side])==set(range(1,rounds+1))
    for values in data[side].values(): assert len(values)==samples
    p95[side]=[sorted(data[side][r])[math.ceil(.95*samples)-1]*1000 for r in range(1,rounds+1)]
med={side:statistics.median(values) for side,values in p95.items()}
result={'old':old,'new':new,'rounds':rounds,'samples_per_round':samples,
        'old_p95_ms':p95['old'],'new_p95_ms':p95['new'],
        'old_median_p95_ms':med['old'],'new_median_p95_ms':med['new'],
        'speedup':med['old']/med['new'] if med['new'] else None,
        'new_is_faster':med['new']<med['old'],
        'minimum_speedup':1.05,
        'accepted':med['new']<med['old']/1.05,
        'payload_integrity':True,'versions_match':True}
with open(out,'w') as f: json.dump(result,f,indent=2); f.write('\n')
print(json.dumps(result,indent=2))
raise SystemExit(0 if result['accepted'] else 1)
PY
