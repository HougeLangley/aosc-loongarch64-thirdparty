#!/usr/bin/env bash
# autopilot.sh —— 常驻自动驾驶：空闲即干活（查新追新 → 补缺包），每 5 分钟一拍
set -uo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
LOG="$ROOT/logs/autopilot.log"
LOCK="${AUTOPILOT_LOCK:-/tmp/autopilot.lock}"
exec 9>"$LOCK"
flock -n 9 || { echo "[autopilot] 已有实例"; exit 0; }
say(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }
trap 'rc=$?; say "autopilot 退出 exit=$rc"' EXIT
say "autopilot 启动 pid=$$"
while true; do
  # lane.sh 在队列空时也会常驻等待——只把真正在编译的 acbs-build 算忙（L615）
  busy=$(pgrep -fc 'acbs-build' || true)
  if (( busy == 0 )); then
    # fd 9 只由 autopilot 主进程持有；子进程继承锁会在父进程退出后造成假存活。
    "$ROOT/scripts/auto-cycle.sh" 9>&- >>"$LOG" 2>&1; rc=$?
    if (( rc == 2 )); then
      "$ROOT/scripts/gap-fill.sh" 9>&- >>"$LOG" 2>&1
    fi
  else
    say "lane 忙（$busy），让行"
  fi
  sleep 300 9>&-
done
