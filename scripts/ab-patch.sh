#!/usr/bin/env bash
# ab-patch.sh —— 补丁 A/B 性能对比（任务⑤第 1 条）
#
# 流程：
#   ① 构建「原始版」：临时移走 autobuild/patches/ 与 beyond 里的优化，构建、留包
#   ② 构建「补丁版」：恢复补丁，构建、留包
#   ③ 基准：对两个包跑同一组命令，各取 N 次，比中位数
#   ④ 结论：补丁版更快则保留补丁；原始版更快则撤掉补丁并记录理由
#
# 用法：ab-patch.sh <包名> [--bench-cmd "<命令>" ...]
#   不给 --bench-cmd 时用内置的通用探针（--version 冷启动 + 大输入处理）
set -uo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
PKG="${1:?用法: ab-patch.sh <包名> [--bench-cmd \"...\"] ...}"
shift
BENCH_CMDS=()
while (( $# )); do
  case "$1" in
    --bench-cmd) BENCH_CMDS+=("$2"); shift 2 ;;
    *) shift ;;
  esac
done

TREE="$ROOT/tree/aosc-loongarch64-thirdparty/packages"
DIR=$(find "$TREE" -mindepth 2 -maxdepth 2 -type d -name "$PKG" 2>/dev/null | head -1)
[[ -n "$DIR" ]] || { echo "  找不到 $PKG 的配方"; exit 1; }
PATCHES="$DIR/autobuild/patches"
RESULT="$ROOT/reports/ab-$PKG.md"
mkdir -p "$ROOT/reports"

have_patches=0
[[ -d "$PATCHES" ]] && (( $(find "$PATCHES" -type f | wc -l) > 0 )) && have_patches=1
if (( ! have_patches )); then
  echo "  $PKG 没有补丁，无需 A/B"; exit 0
fi

echo "  === ① 构建原始版（临时移走补丁）==="
STASH="$ROOT/state/ab-stash-$PKG"; rm -rf "$STASH"; mkdir -p "$STASH"
mv "$PATCHES" "$STASH/patches"
trap '[[ -d "$STASH/patches" && ! -d "$PATCHES" ]] && mv "$STASH/patches" "$PATCHES"' EXIT
"$ROOT/scripts/sync-tree.sh" >/dev/null 2>&1
"$ROOT/scripts/build.sh" "$PKG" >/dev/null 2>&1
ORIG=$(ls -1t "$ROOT/debs/${PKG}_"*.deb 2>/dev/null | head -1)
[[ -n "$ORIG" ]] || { echo "  原始版构建失败"; mv "$STASH/patches" "$PATCHES"; exit 1; }
cp -f "$ORIG" "$STASH/orig.deb"
echo "  原始版: $(basename "$ORIG") $(stat -c%s "$ORIG") 字节"

echo "  === ② 构建补丁版 ==="
mv "$STASH/patches" "$PATCHES"
"$ROOT/scripts/sync-tree.sh" >/dev/null 2>&1
"$ROOT/scripts/build.sh" "$PKG" >/dev/null 2>&1
PATCHED=$(ls -1t "$ROOT/debs/${PKG}_"*.deb 2>/dev/null | head -1)
[[ -n "$PATCHED" ]] || { echo "  补丁版构建失败"; exit 1; }
cp -f "$PATCHED" "$STASH/patched.deb"
echo "  补丁版: $(basename "$PATCHED") $(stat -c%s "$PATCHED") 字节"

# ③ 基准：解包两份，跑同一命令序列
bench_one() {
  local deb="$1" root
  root=$(mktemp -d)
  dpkg-deb -x "$deb" "$root"
  local bin=""
  for c in "usr/bin/$PKG" "usr/bin/${PKG%-*}"; do [[ -x "$root/$c" ]] && { bin="$root/$c"; break; }; done
  if [[ -z "$bin" ]]; then rm -rf "$root"; echo ""; return; fi
  local times=()
  local cmds=("${BENCH_CMDS[@]}")
  (( ${#cmds[@]} == 0 )) && cmds=("$bin --version")
  for i in $(seq 1 ${AB_ROUNDS:-5}); do
    local t0 t1
    t0=$(date +%s%N)
    for c in "${cmds[@]}"; do eval "${c//@BIN@/$bin}" >/dev/null 2>&1; done
    t1=$(date +%s%N)
    times+=($(( (t1-t0)/1000000 )))
  done
  rm -rf "$root"
  printf '%s\n' "${times[@]}" | sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}'
}

echo "  === ③ 基准（各 ${AB_ROUNDS:-5} 轮，取中位数 ms）==="
MO=$(bench_one "$STASH/orig.deb")
MP=$(bench_one "$STASH/patched.deb")
echo "  原始版中位: ${MO:-N/A} ms"
echo "  补丁版中位: ${MP:-N/A} ms"

{
  echo "# 补丁 A/B 对比：$PKG"
  echo ""
  echo "生成: $(date -Is)"
  echo ""
  echo "| 版本 | 产物 | 大小 | 中位耗时 |"
  echo "| --- | --- | --- | --- |"
  echo "| 原始 | $(basename "$ORIG") | $(stat -c%s "$ORIG") | ${MO:-N/A} ms |"
  echo "| 补丁 | $(basename "$PATCHED") | $(stat -c%s "$PATCHED") | ${MP:-N/A} ms |"
  echo ""
} > "$RESULT"

if [[ -n "$MO" && -n "$MP" ]]; then
  if (( MP * 100 < MO * 95 )); then
    echo "  **结论：补丁版明显更快（>5%），保留补丁**" | tee -a "$RESULT"
  elif (( MO * 100 < MP * 95 )); then
    echo "  **结论：原始版明显更快（>5%），建议撤补丁**" | tee -a "$RESULT"
  else
    echo "  **结论：差异在 ±5% 内，视为无显著差异；保留补丁但记录证据**" | tee -a "$RESULT"
  fi
else
  echo "  **结论：无同名主二进制，需人工指定 --bench-cmd**" | tee -a "$RESULT"
fi
echo "  报告: $RESULT"
