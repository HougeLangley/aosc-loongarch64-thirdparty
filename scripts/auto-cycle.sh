#!/usr/bin/env bash
# auto-cycle.sh —— 单包串行完成查新、构建、A/B、发布和配方提交。
# 退出码：0 有发布；1 有失败/阻断；2 无可构建更新（正常空闲）。
set -uo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1
LOG="$ROOT/logs/auto-cycle-$(date +%Y%m%d-%H%M%S).log"
STATE="$ROOT/state/auto-cycle"
TREE="$ROOT/tree/aosc-loongarch64-thirdparty"
FAILED_STATE="$STATE/failed-updates.tsv"
PENDING="$STATE/pending-publish.txt"
mkdir -p "$STATE" "$ROOT/logs"
touch "$FAILED_STATE"
say() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
in_array() { local needle="$1" x; shift; for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done; return 1; }
find_recipe() { find "$TREE/packages" -mindepth 2 -maxdepth 2 -type d -name "$1" 2>/dev/null | head -1; }
spec_ver() { sed -n 's/^VER=//p' "$1" | head -1; }
spec_rel() { sed -n 's/^REL=//p' "$1" | head -1; }
legacy_recipe_fingerprint() {
  find "$1" -type f -print0 | sort -z | xargs -0 sha256sum 2>/dev/null | sha256sum | awk '{print $1}'
}
ab_dispatch_fingerprint() {
  local p="$1"
  awk -v pkg="$p" '
    function dispatch_pkg(s, token) {
      if (s !~ /^[[:space:]]*(if|elif)[[:space:]]+\[\[/) return ""
      if (!match(s, /"\$p"[[:space:]]*==[[:space:]]*[A-Za-z0-9._-]+/)) return ""
      token=substr(s,RSTART,RLENGTH)
      sub(/.*==[[:space:]]*/,"",token)
      return token
    }
    {
      token=dispatch_pkg($0)
      if (token != "") {
        if (active) exit
        if (token == pkg) active=1
      }
      if (active && $0 ~ /^[[:space:]]*(else|fi)([[:space:]]|$)/) exit
      if (active) print
    }
  ' "$ROOT/scripts/auto-cycle.sh" | sha256sum | awk '{print $1}'
}
recipe_fingerprint() {
  local dir="$1" p="${2:-}"
  {
    legacy_recipe_fingerprint "$dir"
    if [[ -n "$p" && -f "$ROOT/scripts/ab-$p.sh" ]]; then
      sha256sum "$ROOT/scripts/ab-$p.sh"
      ab_dispatch_fingerprint "$p"
    fi
  } | sha256sum | awk '{print $1}'
}
restore_spec() {
  local p="$1"
  local spec="${SPEC_BY[$p]}"
  sed -i -E "s/^VER=.*/VER=${OLD_VER[$p]}/" "$spec"
  if [[ -n "${OLD_REL[$p]}" ]]; then
    sed -i -E "s/^REL=.*/REL=${OLD_REL[$p]}/" "$spec"
  else
    sed -i '/^REL=/d' "$spec"
  fi
  say "    $p: 已恢复 VER=${OLD_VER[$p]}，失败升级不会伪装成最新"
}
record_failure() {
  local p="$1" up="$2" stage="$3" hash tmp
  hash="$(recipe_fingerprint "$(dirname "${SPEC_BY[$p]}")" "$p")"
  tmp="$(mktemp "$STATE/failed-updates.XXXXXX")"
  awk -F'\t' -v p="$p" -v v="$up" '$1 != p || $2 != v' "$FAILED_STATE" > "$tmp"
  printf '%s\t%s\t%s\t%s\t%s\n' "$p" "$up" "$hash" "$(date -Is)" "$stage" >> "$tmp"
  mv "$tmp" "$FAILED_STATE"
}
clear_failure() {
  local p="$1" up="$2" tmp
  tmp="$(mktemp "$STATE/failed-updates.XXXXXX")"
  awk -F'\t' -v p="$p" -v v="$up" '$1 != p || $2 != v' "$FAILED_STATE" > "$tmp"
  mv "$tmp" "$FAILED_STATE"
}
known_unchanged_failure() {
  local p="$1" up="$2" hash="$3" legacy="$4"
  local rp rv rh rt stage failed_at probe_mtime probe="$ROOT/scripts/ab-$p.sh"
  while IFS=$'\t' read -r rp rv rh rt stage; do
    [[ "$rp" == "$p" && "$rv" == "$up" && "$stage" != publish ]] || continue
    # tag 已出现但 release 资产未发布是上游时序，不是配方永久失败。
    [[ "$stage" == defer ]] && continue
    [[ "$rh" == "$hash" ]] && return 0
    if [[ "$rh" == "$legacy" ]]; then
      # 旧记录没有探针指纹：只有探针在失败之后发生实质变化才重试。
      if [[ -f "$probe" ]]; then
        probe_mtime="$(stat -c %Y "$probe")"
        failed_at="$(date -d "$rt" +%s)"
        (( probe_mtime > failed_at )) && continue
      fi
      return 0
    fi
  done < "$FAILED_STATE"
  return 1
}
commit_recipes() {
  local -a paths=()
  local p d rel
  for p in "$@"; do
    d="$(find_recipe "$p")"
    [[ -n "$d" ]] || continue
    rel="${d#"$TREE/"}"
    paths+=("$rel")
  done
  (( ${#paths[@]} )) || return 0
  git -C "$TREE" add -- "${paths[@]}" || return 1
  git -C "$TREE" diff --cached --quiet && return 0
  git -C "$TREE" -c user.name="HougeLangley" -c user.email="houge@aosc.io" \
    commit -q -m "auto: bump $* to latest upstream"
}

say "=== 周期开始 dry-run=$DRY ==="

# 上轮若已完成构建/A/B 但网络发布失败，先只重试发布，不重复编译。
if [[ -s "$PENDING" && $DRY -eq 0 ]]; then
  mapfile -t PENDING_PKGS < <(sed '/^$/d' "$PENDING")
  say "④ 重试上轮待发布：${PENDING_PKGS[*]}"
  if "$ROOT/scripts/publish.sh" "${PENDING_PKGS[@]}" >>"$LOG" 2>&1; then
    commit_recipes "${PENDING_PKGS[@]}" && say "  待发布包已发布并提交"
    : > "$PENDING"
  else
    say "  待发布重试仍失败，保留下轮任务"
  fi
fi

say "① 查新"
if [[ ! -x "$ROOT/scripts/preflight-version.sh" ]]; then
  say "  跳过：没有 preflight-version.sh"
  exit 2
fi
"$ROOT/scripts/preflight-version.sh" >"$STATE/updates.log" 2>&1
mapfile -t STALE < <(sed -n 's/^ *\[陈旧\] \([^ ]*\).*/\1/p' "$STATE/updates.log" | sort -u)
if (( ${#STALE[@]} == 0 )); then
  say "  无新版本，周期结束"
  exit 2
fi
say "  发现 ${#STALE[@]} 个包有新版本：${STALE[*]}"
[[ $DRY -eq 1 ]] && { say "  dry-run，停止"; exit 0; }

say "①.5 写回新 VER"
SKIPLIST="$ROOT/state/skip-auto.txt"
declare -a QUEUE=() BLOCKED=()
declare -A OLD_VER=() OLD_REL=() NEW_VER=() SPEC_BY=()
: > "$STATE/queue.txt"
while read -r line; do
  p="$(sed -n 's/^ *\[陈旧\] \([^ ]*\).*/\1/p' <<<"$line")"
  up="$(sed -n 's/.*上游最新=\([^ ]*\).*/\1/p' <<<"$line")"
  [[ -n "$p" && -n "$up" ]] || continue
  if grep -qx "$p" "$SKIPLIST" 2>/dev/null; then
    say "    $p: 在跳过名单，不自动追新"
    BLOCKED+=("$p")
    continue
  fi
  recipe="$(find_recipe "$p")"
  spec="$recipe/spec"
  if [[ -z "$recipe" || ! -f "$spec" ]]; then
    say "    $p: 找不到 spec，不进入构建队列"
    BLOCKED+=("$p")
    continue
  fi
  old="$(spec_ver "$spec")"
  [[ -n "$old" ]] || { BLOCKED+=("$p"); continue; }
  OLD_VER[$p]="$old"
  OLD_REL[$p]="$(spec_rel "$spec")"
  NEW_VER[$p]="$up"
  SPEC_BY[$p]="$spec"
  sed -i -E "s/^REL=.*/REL=1/" "$spec"
  sed -i -E "s/^VER=.*/VER=$up/" "$spec"
  if [[ "$(spec_ver "$spec")" != "$up" ]]; then
    say "    $p: VER 写回失败"
    restore_spec "$p"
    BLOCKED+=("$p")
    continue
  fi
  if [[ "$p" == wowtype && -x "$ROOT/scripts/wowtype-release-ready.sh" ]]; then
    ready_log="$STATE/wowtype-release-ready.log"
    "$ROOT/scripts/wowtype-release-ready.sh" "$up" "$recipe" >"$ready_log" 2>&1
    ready_rc=$?
    if [[ $ready_rc -eq 2 ]]; then
      say "    $p $up: release 资产尚未就绪，下轮重试（非配方失败）"
      restore_spec "$p"
      BLOCKED+=("$p")
      continue
    elif [[ $ready_rc -ne 0 ]]; then
      say "    $p $up: 官方数据清单与配方冲突，禁止构建"
      cat "$ready_log" >>"$LOG"
      record_failure "$p" "$up" preflight
      restore_spec "$p"
      BLOCKED+=("$p")
      continue
    fi
    cat "$ready_log" >>"$LOG"
  fi
  hash="$(recipe_fingerprint "$recipe" "$p")"
  legacy_hash="$(legacy_recipe_fingerprint "$recipe")"
  if known_unchanged_failure "$p" "$up" "$hash" "$legacy_hash"; then
    say "    $p $up: 相同配方已有失败记录；等待配方修正，不重复空转"
    restore_spec "$p"
    BLOCKED+=("$p")
    continue
  fi
  QUEUE+=("$p")
  echo "$p" >> "$STATE/queue.txt"
  say "    $p: VER $old -> $up (REL=1)"
done < <(grep '^ *\[陈旧\]' "$STATE/updates.log")

if (( ${#QUEUE[@]} == 0 )); then
  "$ROOT/scripts/sync-tree.sh" >/dev/null 2>&1 || true
  say "  没有可执行更新的包（阻断 ${#BLOCKED[@]} 个）"
  exit 1
fi
"$ROOT/scripts/sync-tree.sh" >/dev/null 2>&1 || { say "  同步 ABBS 树失败"; exit 1; }

say "② 构建（串行，每包使用全部线程）"
declare -a FAILED=() AB_FAILED=()
for p in "${QUEUE[@]}"; do
  say "  构建 $p"
  # mise 的 2026.11.12 全 workspace LTO 在 3600 秒仍活跃推进；预算与回收分开处理。
  budget="${BUILD_TIMEOUT:-3600}"
  [[ "$p" == mise ]] && budget="${BUILD_TIMEOUT_MISE:-7200}"
  if timeout -k 15s "$budget" "$ROOT/scripts/build.sh" "$p" >>"$LOG" 2>&1; then
    say "    $p OK"
  else
    say "    $p 构建失败"
    FAILED+=("$p")
    failure_stage=build
    if [[ "$p" == wowtype ]] && grep -q 'curl: (22).*404' "$ROOT/logs/$p.log" 2>/dev/null; then
      failure_stage=defer
      say "    $p: 数据资产 404，按 tag-before-release 暂时失败处理"
    fi
    record_failure "$p" "${NEW_VER[$p]}" "$failure_stage"
    restore_spec "$p"
  fi
done

say "③ 择优（所有升级都必须有已批准的性能探针）"
AB_ROUNDS="${AB_ROUNDS:-3}"
for p in "${QUEUE[@]}"; do
  in_array "$p" "${FAILED[@]}" && continue
  ok=0
  if [[ "$p" == valkey && -x "$ROOT/scripts/ab-valkey.sh" ]]; then
    say "  $p: valkey-benchmark A/B ${OLD_VER[$p]} -> ${NEW_VER[$p]}"
    AB_ROUNDS="$AB_ROUNDS" timeout 2400 "$ROOT/scripts/ab-valkey.sh" "${OLD_VER[$p]}" "${NEW_VER[$p]}" "$AB_ROUNDS" >>"$LOG" 2>&1 && ok=1
  elif [[ "$p" == pueue && -x "$ROOT/scripts/ab-pueue.sh" ]]; then
    say "  $p: pueue daemon/client A/B ${OLD_VER[$p]} -> ${NEW_VER[$p]}"
    AB_ROUNDS="$AB_ROUNDS" timeout 2400 "$ROOT/scripts/ab-pueue.sh" "${OLD_VER[$p]}" "${NEW_VER[$p]}" "$AB_ROUNDS" >>"$LOG" 2>&1 && ok=1
  elif [[ "$p" == muffet && -x "$ROOT/scripts/ab-muffet.sh" ]]; then
    say "  $p: muffet local-site A/B ${OLD_VER[$p]} -> ${NEW_VER[$p]}"
    timeout 2400 "$ROOT/scripts/ab-muffet.sh" "${OLD_VER[$p]}" "${NEW_VER[$p]}" "$AB_ROUNDS" >>"$LOG" 2>&1 && ok=1
  elif [[ "$p" == wowtype && -x "$ROOT/scripts/ab-wowtype.sh" ]]; then
    say "  $p: wowtype-bench ${OLD_VER[$p]} -> ${NEW_VER[$p]}"
    timeout 2400 "$ROOT/scripts/ab-wowtype.sh" "${OLD_VER[$p]}" "${NEW_VER[$p]}" "$AB_ROUNDS" >>"$LOG" 2>&1 && ok=1
  elif [[ "$p" == v2raya && -x "$ROOT/scripts/ab-v2raya.sh" ]]; then
    say "  $p: v2raya-core SOCKS A/B ${OLD_VER[$p]} -> ${NEW_VER[$p]}"
    timeout 2400 "$ROOT/scripts/ab-v2raya.sh" "${OLD_VER[$p]}" "${NEW_VER[$p]}" "$AB_ROUNDS" >>"$LOG" 2>&1 && ok=1
  else
    say "  $p: 无专用 A/B 探针，禁止自动发布"
    echo "$p" >> "$STATE/need-bench.txt"
  fi
  if (( ok == 1 )); then
    say "    $p A/B 通过"
  else
    say "    $p A/B 未通过，发布阻断"
    AB_FAILED+=("$p")
    record_failure "$p" "${NEW_VER[$p]}" ab
    restore_spec "$p"
  fi
done

say "④ 发布"
declare -a GOOD=()
for p in "${QUEUE[@]}"; do
  in_array "$p" "${FAILED[@]}" && continue
  in_array "$p" "${AB_FAILED[@]}" && continue
  GOOD+=("$p")
done
# 把失败包的恢复同步到 ABBS，避免下一包/下一周期误用已失败的版本。
"$ROOT/scripts/sync-tree.sh" >/dev/null 2>&1 || true
if (( ${#GOOD[@]} == 0 )); then
  say "  没有可发布的包；构建失败 ${#FAILED[@]}，A/B 阻断 ${#AB_FAILED[@]}"
  exit 1
fi
say "  发布 ${#GOOD[@]} 个：${GOOD[*]}"
if ! "$ROOT/scripts/publish.sh" "${GOOD[@]}" >>"$LOG" 2>&1; then
  printf '%s\n' "${GOOD[@]}" > "$PENDING"
  say "  发布失败；保留新 VER 并写入 pending-publish，下轮只重试发布"
  exit 1
fi
for p in "${GOOD[@]}"; do clear_failure "$p" "${NEW_VER[$p]}"; done
if commit_recipes "${GOOD[@]}"; then
  say "  配方已提交"
else
  say "  配方提交失败"
  exit 1
fi
say "=== 周期结束：成功 ${#GOOD[@]} / 构建失败 ${#FAILED[@]} / A/B 阻断 ${#AB_FAILED[@]} / 其他阻断 ${#BLOCKED[@]} ==="
(( ${#FAILED[@]} == 0 && ${#AB_FAILED[@]} == 0 ))
