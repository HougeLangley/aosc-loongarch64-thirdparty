#!/usr/bin/env bash
# ab-muffet.sh OLD_VER NEW_VER [ROUNDS] — real local-site correctness + throughput A/B.
set -euo pipefail
OLD="${1:-2.11.8}"; NEW="${2:-2.11.9}"; ROUNDS="${3:-3}"
ROOT=/home/houge/build
LINKS="${AB_LINKS:-3000}"
CONN="${AB_CONNECTIONS:-64}"
[[ "$ROUNDS" =~ ^[1-9][0-9]*$ && "$LINKS" =~ ^[1-9][0-9]*$ && "$CONN" =~ ^[1-9][0-9]*$ ]]
T="$(mktemp -d /tmp/ab-muffet.XXXXXX)"
SERVER_PID=''
cleanup() {
  if [[ -n "$SERVER_PID" ]]; then kill "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" 2>/dev/null || true; fi
}
trap cleanup EXIT HUP INT TERM
mkdir -p "$T/old" "$T/new" "$ROOT/reports"
dpkg-deb -x "$ROOT/debs/muffet_${OLD}-1_loongarch64.deb" "$T/old"
dpkg-deb -x "$ROOT/debs/muffet_${NEW}-1_loongarch64.deb" "$T/new"
OLD_BIN="$T/old/usr/bin/muffet"; NEW_BIN="$T/new/usr/bin/muffet"
[[ "$("$OLD_BIN" --version)" == "$OLD" ]]
[[ "$("$NEW_BIN" --version)" == "$NEW" ]]
cat > "$T/server.py" <<'PY'
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys
links=int(sys.argv[2])
class Server(ThreadingHTTPServer):
 daemon_threads=True
 request_queue_size=1024
class Handler(BaseHTTPRequestHandler):
 protocol_version='HTTP/1.1'
 def do_GET(self):
  path=self.path.split('?',1)[0]
  if path=='/bench':
   body=('<!doctype html><html><body>'+''.join(f'<a href="/ok/{i}">{i}</a>' for i in range(links))+'</body></html>').encode()
   code=200
  elif path.startswith('/ok/') or path=='/alive': body=b'ok'; code=200
  elif path=='/good': body=b'<a href="/alive">ok</a>'; code=200
  elif path=='/broken': body=b'<a href="/missing">bad</a>'; code=200
  else: body=b'missing'; code=404
  self.send_response(code)
  self.send_header('Content-Type','text/html; charset=utf-8')
  self.send_header('Content-Length',str(len(body)))
  self.end_headers()
  self.wfile.write(body)
 def log_message(self,*args): pass
s=Server(('127.0.0.1',0),Handler)
Path(sys.argv[1]).write_text(str(s.server_address[1]))
s.serve_forever(poll_interval=0.05)
PY
# Start in the main shell: teardown owns this exact PID, never a command-substitution subshell.
python3 "$T/server.py" "$T/port" "$LINKS" >"$T/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 100); do [[ -s "$T/port" ]] && break; kill -0 "$SERVER_PID"; sleep 0.05; done
PORT="$(cat "$T/port")"
BASE="http://127.0.0.1:$PORT"
curl -fsS "$BASE/alive" >/dev/null
check_function() {
  local side="$1" bin="$2" rc
  "$bin" --one-page-only --format=json "$BASE/good" >"$T/$side-good.json"
  set +e
  "$bin" --one-page-only --format=json "$BASE/broken" >"$T/$side-broken.json" 2>"$T/$side-broken.stderr"
  rc=$?
  set -e
  [[ $rc -eq 1 ]]
  python3 - "$T/$side-good.json" "$T/$side-broken.json" "$BASE" <<'PY'
import json,sys
ok=json.load(open(sys.argv[1])); bad=json.load(open(sys.argv[2])); base=sys.argv[3]
assert ok==[],ok
assert len(bad)==1 and bad[0]['url']==base+'/broken',bad
links=bad[0]['links']
assert len(links)==1 and links[0]['url']==base+'/missing' and links[0]['error']=='404',bad
print('functional PASS:',sys.argv[2])
PY
}
check_function old "$OLD_BIN"
check_function new "$NEW_BIN"
: > "$T/results.csv"
run_side() {
  local side="$1" round="$2" bin start end rc
  [[ "$side" == old ]] && bin="$OLD_BIN" || bin="$NEW_BIN"
  start="$(date +%s%N)"
  set +e
  "$bin" --max-connections="$CONN" --max-connections-per-host="$CONN" --timeout=10 \
    --one-page-only --format=json "$BASE/bench" >"$T/perf-$round-$side.json" 2>"$T/perf-$round-$side.stderr"
  rc=$?
  set -e
  end="$(date +%s%N)"
  [[ $rc -eq 0 ]] || { cat "$T/perf-$round-$side.stderr" >&2; return 1; }
  python3 - "$T/perf-$round-$side.json" "$side" "$round" "$start" "$end" "$LINKS" >>"$T/results.csv" <<'PY'
import json,sys
p,side,r,start,end,n=sys.argv[1:]
result=json.load(open(p))
assert result==[],f'unexpected crawl errors: {result[:3]}'
elapsed=(int(end)-int(start))/1e9
requests=int(n)+1
assert elapsed>0
print(f'{side},{r},{requests},{elapsed:.6f},{requests/elapsed:.2f}')
PY
}
for round in $(seq 1 "$ROUNDS"); do
  if (( round % 2 )); then order=(old new); else order=(new old); fi
  for side in "${order[@]}"; do run_side "$side" "$round"; done
done
python3 - "$T/results.csv" "$OLD" "$NEW" "$ROUNDS" "$LINKS" "$CONN" "$ROOT/reports/ab-muffet.md" <<'PY'
import csv,statistics,sys
csv_path,old,new,rounds,links,conn,out=sys.argv[1:]
rows=list(csv.DictReader(open(csv_path),fieldnames=['side','round','requests','seconds','rps']))
vals={s:[float(r['rps']) for r in rows if r['side']==s] for s in ('old','new')}
assert len(vals['old'])==len(vals['new'])==int(rounds),rows
om=statistics.median(vals['old']); nm=statistics.median(vals['new']); speed=nm/om
accepted=nm>om*1.05
lines=['# muffet version A/B','',f'- Old: {old}',f'- New: {new}',
 f'- Requests per round: {int(links)+1}; max connections: {conn}; rounds: {rounds}',
 '- Workload: real old/new binaries crawl an isolated local site; 200/404 JSON behavior checked before timing.','',
 '| Round | Old requests/s | New requests/s |','| --- | ---: | ---: |']
for i in range(int(rounds)): lines.append(f'| {i+1} | {vals["old"][i]:.2f} | {vals["new"][i]:.2f} |')
lines += ['',f'Median: **{om:.2f} → {nm:.2f} requests/s**; speedup **{speed:.3f}×**.',
 f'Decision: **{"ACCEPT" if accepted else "REJECT"}** (requires >1.05×).','']
text='\n'.join(lines)
open(out,'w').write(text)
print(text)
raise SystemExit(0 if accepted else 1)
PY
