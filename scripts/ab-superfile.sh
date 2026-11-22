#!/usr/bin/env bash
# ab-superfile.sh OLD_VER NEW_VER [ROUNDS]
# Real TUI workload: launch in a controlled directory, wait for the first frame
# containing a known file, then quit through the configured q hotkey.
set -euo pipefail
OLD_VER="${1:?old version}"; NEW_VER="${2:?new version}"; ROUNDS="${3:-3}"
ROOT="${BUILD_ROOT:-$HOME/build}"; FILES="${AB_FILES:-2000}"
[[ "$ROUNDS" =~ ^[1-9][0-9]*$ && "$FILES" =~ ^[1-9][0-9]*$ ]]
find_deb() {
  local ver="$1" override="$2"; local -a hits=()
  if [[ -n "$override" ]]; then [[ -f "$override" ]]; readlink -f "$override"; return; fi
  shopt -s nullglob
  hits=("$ROOT/debs/superfile_${ver}-"*_loongarch64.deb "$ROOT/debs/superfile_${ver}-"*_all.deb)
  shopt -u nullglob
  [[ ${#hits[@]} -eq 1 ]] || { echo "expected one superfile $ver deb, got ${#hits[@]}" >&2; return 1; }
  readlink -f "${hits[0]}"
}
OLD_DEB="$(find_deb "$OLD_VER" "${AB_OLD_DEB:-}")"; NEW_DEB="$(find_deb "$NEW_VER" "${AB_NEW_DEB:-}")"
[[ "$OLD_DEB" != "$NEW_DEB" ]]
T="$(mktemp -d /tmp/ab-superfile.XXXXXX)"; mkdir -p "$T/old" "$T/new" "$ROOT/reports"
dpkg-deb -x "$OLD_DEB" "$T/old"; dpkg-deb -x "$NEW_DEB" "$T/new"
OLD_PKGVER="$(dpkg-deb -f "$OLD_DEB" Version)"; NEW_PKGVER="$(dpkg-deb -f "$NEW_DEB" Version)"
[[ "$(dpkg-deb -f "$OLD_DEB" Package)" == superfile && "$(dpkg-deb -f "$NEW_DEB" Package)" == superfile ]]
OLD_BIN="$T/old/usr/bin/superfile"; NEW_BIN="$T/new/usr/bin/superfile"; [[ -x "$OLD_BIN" && -x "$NEW_BIN" ]]
"$OLD_BIN" --version | grep -F "v$OLD_VER" >/dev/null
"$NEW_BIN" --version | grep -F "v$NEW_VER" >/dev/null
python3 - "$OLD_BIN" "$NEW_BIN" "$T" "$ROUNDS" "$FILES" "$OLD_PKGVER" "$NEW_PKGVER" "$ROOT/reports/ab-superfile.md" <<'PY'
import fcntl,json,os,pty,select,signal,statistics,struct,sys,termios,time
from pathlib import Path
oldbin,newbin,tmp,rounds,nfiles,oldver,newver,report=sys.argv[1:]
rounds=int(rounds); nfiles=int(nfiles); root=Path(tmp)
fixture=root/'fixture'; fixture.mkdir()
for i in range(nfiles): (fixture/f'benchmark-marker-{i:04d}.txt').write_text(str(i))
marker=b'benchmark-marker-0000.txt'; results=[]

def run(side,warmup=False):
 bin=oldbin if side=='old' else newbin
 home=root/(side+'-home'); home.mkdir(exist_ok=True)
 pid,master=pty.fork()
 if pid==0:
  os.chdir(fixture)
  env={'PATH':'/usr/bin:/bin','HOME':str(home),'XDG_CONFIG_HOME':str(home/'config'),'XDG_DATA_HOME':str(home/'data'),'XDG_CACHE_HOME':str(home/'cache'),'TERM':'xterm-256color','NO_COLOR':'1'}
  os.execvpe(bin,['superfile',str(fixture)],env)
 fcntl.ioctl(master,termios.TIOCSWINSZ,struct.pack('HHHH',40,120,0,0))
 start=time.monotonic(); first=None; status=None; data=bytearray(); reaped=False
 def drain(duration):
  deadline=time.monotonic()+duration
  while time.monotonic()<deadline:
   r,_,_=select.select([master],[],[],min(.05,max(0,deadline-time.monotonic())))
   if not r: continue
   try: chunk=os.read(master,65536)
   except OSError: return False
   if not chunk: return False
   if len(data)<2_000_000: data.extend(chunk)
  return True
 try:
  deadline=time.monotonic()+10
  while time.monotonic()<deadline:
   r,_,_=select.select([master],[],[],min(.1,max(0,deadline-time.monotonic())))
   if not r: continue
   try: chunk=os.read(master,65536)
   except OSError: break
   if not chunk: break
   if len(data)<2_000_000: data.extend(chunk)
   if marker in data:
    first=time.monotonic()-start; break
  if first is None: raise RuntimeError(f'{side}: first frame did not contain marker; tail={bytes(data[-1000:])!r}')
  # A real user cannot quit before the initial terminal negotiation finishes.
  drain(.5)
  os.write(master,b'q')
  # Upstream v1.6.0 model.go intentionally ignores the first key when firstUse
  # is true. Warm-up acknowledges that state; measured runs use one q only.
  if warmup:
   warm_deadline=time.monotonic()+.5
   while time.monotonic()<warm_deadline:
    got,st=os.waitpid(pid,os.WNOHANG)
    if got: status=st; reaped=True; break
    drain(.02)
   if status is None: os.write(master,b'q')
  deadline=time.monotonic()+5
  while status is None and time.monotonic()<deadline:
   got,st=os.waitpid(pid,os.WNOHANG)
   if got: status=st; reaped=True; break
   drain(.02)
  if status is None: raise RuntimeError(f'{side}: configured q did not exit')
  code=os.waitstatus_to_exitcode(status)
  if code!=0: raise RuntimeError(f'{side}: q exit={code}')
  if not warmup: results.append({'side':side,'startup_ms':first*1000,'frames_per_s':1/first})
  return first
 finally:
  if not reaped:
   try: os.kill(pid,signal.SIGKILL)
   except ProcessLookupError: pass
   try: os.waitpid(pid,0)
   except ChildProcessError: pass
  os.close(master)

# Generate each version's default config before any timed sample.
for side in ('old','new'): run(side,True)
for r in range(rounds):
 order=('old','new') if r%2==0 else ('new','old')
 for side in order: run(side)
vals={s:[r['frames_per_s'] for r in results if r['side']==s] for s in ('old','new')}
lat={s:[r['startup_ms'] for r in results if r['side']==s] for s in ('old','new')}
om=statistics.median(vals['old']); nm=statistics.median(vals['new']); accepted=nm>om*1.05
lines=['# superfile original/candidate real-TUI A/B','',f'- Old: {oldver}',f'- New: {newver}',f'- Directory entries: {nfiles}; rounds: {rounds}',
 '- Every measured launch rendered `benchmark-marker-0000.txt` and exited 0 with one configured `q`; warm-ups explicitly acknowledge upstream firstUse key swallowing.',
 '- Metric: first rendered marker frames/s (higher is better); 500 ms post-frame wait and q teardown are not included in startup latency.','',
 '| Round | Old first-frame ms | New first-frame ms | Old frames/s | New frames/s |','| --- | ---: | ---: | ---: | ---: |']
for i in range(rounds): lines.append(f'| {i+1} | {lat["old"][i]:.2f} | {lat["new"][i]:.2f} | {vals["old"][i]:.2f} | {vals["new"][i]:.2f} |')
lines += ['',f'Median first-frame latency: **{statistics.median(lat["old"]):.2f} → {statistics.median(lat["new"]):.2f} ms**.',
 f'Median throughput: **{om:.2f} → {nm:.2f} frames/s**; speedup **{nm/om:.3f}×**.',
 f'Decision: **{"ACCEPT" if accepted else "REJECT"}** (new median must exceed old by >1.05×).','']
text='\n'.join(lines); Path(report).write_text(text); print(text)
raise SystemExit(0 if accepted else 1)
PY
