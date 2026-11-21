#!/usr/bin/env python3
"""Kill only process groups whose cwd belongs to one ACBS temporary build.

Called through non-interactive sudo by build.sh after normal exit or timeout.
The ACBS id is taken from ACBS's own "Build log:" line, never from process-name
pattern matching.  This handles pexpect/script children that created a new session.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import signal
import sys
import time

if len(sys.argv) != 3:
    raise SystemExit("usage: cleanup-acbs-tree.py BUILD_LOG PACKAGE")
log = Path(sys.argv[1])
package = sys.argv[2]
if not re.fullmatch(r"[A-Za-z0-9+._-]+", package):
    raise SystemExit("invalid package name")
if not log.is_file():
    raise SystemExit(0)
text = log.read_text(errors="replace")
text = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", text)
pattern = re.compile(
    r"Build log:\s*.*?(?P<needle>/acbs\.[A-Za-z0-9_.-]+/"
    + re.escape(package)
    + r")(?:/|\r?$)",
    re.MULTILINE,
)
matches = list(pattern.finditer(text))
if not matches:
    raise SystemExit(0)
needle = matches[-1].group("needle")
own_pgid = os.getpgid(0)
matched: dict[int, set[int]] = {}
for entry in Path("/proc").iterdir():
    if not entry.name.isdigit():
        continue
    pid = int(entry.name)
    if pid == os.getpid():
        continue
    try:
        cwd = os.readlink(entry / "cwd")
        if needle not in cwd:
            continue
        pgid = os.getpgid(pid)
        if pgid <= 1 or pgid == own_pgid:
            raise RuntimeError(f"refusing unsafe process group {pgid}")
        matched.setdefault(pgid, set()).add(pid)
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        continue

def _pgid_alive(pgid: int) -> bool:
    try:
        os.killpg(pgid, 0)
        return True
    except ProcessLookupError:
        return False


if not matched:
    print(f"ACBS cleanup: no live processes for {needle}")
    raise SystemExit(0)
for pgid, pids in matched.items():
    print(f"ACBS cleanup: TERM pgid={pgid} pids={sorted(pids)} path={needle}")
    os.killpg(pgid, signal.SIGTERM)
deadline = time.monotonic() + 8
while time.monotonic() < deadline:
    if not any(_pgid_alive(pgid) for pgid in matched):
        break
    time.sleep(0.1)
for pgid in matched:
    if _pgid_alive(pgid):
        print(f"ACBS cleanup: KILL pgid={pgid}")
        os.killpg(pgid, signal.SIGKILL)
