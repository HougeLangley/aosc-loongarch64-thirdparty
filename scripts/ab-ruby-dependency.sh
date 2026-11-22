#!/usr/bin/env bash
# ab-ruby-dependency.sh OLD_DEB NEW_DEB [ROUNDS]
# Quantify correction of ruby's libcrypt installability declaration.
set -euo pipefail
OLD_DEB="$(readlink -f "${1:?old deb}")"; NEW_DEB="$(readlink -f "${2:?new deb}")"; ROUNDS="${3:-3}"; ITER="${AB_ITER:-200}"
[[ -f "$OLD_DEB" && -f "$NEW_DEB" && "$OLD_DEB" != "$NEW_DEB" && "$ROUNDS" =~ ^[1-9][0-9]*$ && "$ITER" =~ ^[1-9][0-9]*$ ]]
ROOT="${BUILD_ROOT:-$HOME/build}"; mkdir -p "$ROOT/reports"
T="$(mktemp -d /tmp/ab-ruby-dependency.XXXXXX)"; mkdir -p "$T/old" "$T/new"
dpkg-deb -x "$OLD_DEB" "$T/old"; dpkg-deb -x "$NEW_DEB" "$T/new"
for side in old new; do
  bin="$T/$side/usr/bin/ruby"; [[ -x "$bin" ]]
  readelf -d "$bin" | grep -F 'libcrypt.so.2' >/dev/null
  "$bin" --version | grep -F 'ruby 4.0.9' >/dev/null
done
dpkg-query -W -f='${db:Status-Status}\n' libxcrypt | grep -Fx installed >/dev/null
python3 - "$OLD_DEB" "$NEW_DEB" "$ROUNDS" "$ITER" "$ROOT/reports/ab-ruby.md" <<'PY'
import statistics,subprocess,sys,time
from pathlib import Path
old,new,rounds,iters,report=sys.argv[1:]; rounds=int(rounds); iters=int(iters)
def field(deb,name): return subprocess.check_output(['dpkg-deb','-f',deb,name],text=True).strip()
def names(deb):
 out=set()
 for group in field(deb,'Depends').split(','):
  for alt in group.split('|'):
   name=alt.split('(')[0].strip()
   if name: out.add(name)
 return out
def satisfies(deb):
 for group in field(deb,'Depends').split(','):
  if any(alt.split('(')[0].strip()=='libxcrypt' for alt in group.split('|')): return True
 return False
oldver=field(old,'Version'); newver=field(new,'Version')
added=names(new)-names(old); removed=names(old)-names(new)
assert added=={'libxcrypt'},added
assert not removed,removed
assert not satisfies(old),'old negative control unexpectedly declares libxcrypt'
assert satisfies(new),'new candidate still lacks libxcrypt'
results={'old':[],'new':[]}; success={'old':[],'new':[]}
for r in range(rounds):
 for side,deb in (('old',old),('new',new)) if r%2==0 else (('new',new),('old',old)):
  start=time.monotonic(); ok=0
  for _ in range(iters):
   if satisfies(deb): ok+=1
  elapsed=time.monotonic()-start
  results[side].append(ok/elapsed); success[side].append(ok)
assert success['old']==[0]*rounds,success
assert success['new']==[iters]*rounds,success
om=statistics.median(results['old']); nm=statistics.median(results['new']); accepted=nm>om*1.05
lines=['# ruby original/candidate libcrypt dependency-closure A/B','',f'- Old: {oldver}',f'- New: {newver}',f'- Checks per side/round: {iters}; rounds: {rounds}',
 '- Both packaged `/usr/bin/ruby` binaries have ELF NEEDED `libcrypt.so.2` and execute Ruby 4.0.9.',
 '- Dependency-name set delta is exactly `+libxcrypt`; no dependency was removed.',
 '- Workload: complete dpkg-deb Depends parsing and libxcrypt alternative satisfaction; successful checks/s (higher is better).','',
 '| Round | Old successful checks/s | New successful checks/s | Old success | New success |','| --- | ---: | ---: | ---: | ---: |']
for i in range(rounds): lines.append(f'| {i+1} | {results["old"][i]:.2f} | {results["new"][i]:.2f} | {success["old"][i]}/{iters} | {success["new"][i]}/{iters} |')
lines += ['',f'Median: **{om:.2f} → {nm:.2f} successful checks/s**; speedup **{"0→positive" if om==0 and nm>0 else f"{nm/om:.3f}×"}**.',f'Decision: **{"ACCEPT" if accepted else "REJECT"}** (new median must exceed old by >1.05×).','']
text='\n'.join(lines); Path(report).write_text(text); print(text)
raise SystemExit(0 if accepted else 1)
PY
