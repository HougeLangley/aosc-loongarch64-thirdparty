#!/usr/bin/env bash
# autopilot-guard.sh —— cron 保活入口：以 flock 的真实持有状态为准，不用 pgrep 自匹配。
set -uo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
LOCK="${AUTOPILOT_LOCK:-/tmp/autopilot.lock}"
LOG="$ROOT/logs/autopilot-guard.log"
mkdir -p "$ROOT/logs"

# autopilot 主进程持有 fd 9；其子进程必须显式关闭 fd 9，避免孤儿进程占锁。
if ! flock -n "$LOCK" -c true; then
  exit 0
fi

if [[ "${AUTOPILOT_GUARD_DRY_RUN:-0}" == 1 ]]; then
  echo "autopilot guard: lock is free; would start $ROOT/scripts/autopilot.sh"
  exit 0
fi

printf '[%s] guard: lock free, starting autopilot\n' "$(date -Is)" >> "$LOG"
cd "$ROOT" || exit 1
nohup setsid "$ROOT/scripts/autopilot.sh" >> "$ROOT/logs/autopilot-guard.log" 2>&1 &
exit 0
