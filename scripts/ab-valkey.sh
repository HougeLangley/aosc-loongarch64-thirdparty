#!/usr/bin/env bash
# ab-valkey.sh —— valkey 的补丁 A/B 压测（任务②的具体实现）
#
# 补丁 `valkey-5.0-use-system-jemalloc.patch` 把内置 jemalloc 换成系统 libjemalloc，
# 影响的是内存分配器路径——只有跑真实负载才测得出来。
# valkey 自带 valkey-benchmark，用它做 A/B。
#
# 流程：
#   ① 构建原始版（移走 patches）· ② 构建补丁版 · ③ 各自起 server 跑 benchmark
#   ④ 取中位数比 ops/sec，>5% 才算显著
set -uo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
PKG=valkey
PORTA=${AB_PORT_A:-7801}; PORTB=${AB_PORT_B:-7802}
REQS="${AB_REQS:-200000}"; CLIENTS="${AB_CLIENTS:-50}"; ROUNDS="${AB_ROUNDS:-3}"
TREE="$ROOT/tree/aosc-loongarch64-thirdparty/packages"
DIR=$(find "$TREE" -mindepth 2 -maxdepth 2 -type d -name "$PKG" | head -1)
STASH="$ROOT/state/ab-$PKG"; RESULT="$ROOT/reports/ab-$PKG.md"
mkdir -p "$ROOT/reports" "$ROOT/state"

build_variant() {   # $1=orig|patched  → 输出 deb 路径
  local want="$1"
  if [[ "$want" == orig ]]; then
    mv "$DIR/autobuild/patches" "$STASH/patches-off" 2>/dev/null || true
  else
    mv "$STASH/patches-off" "$DIR/autobuild/patches" 2>/dev/null || true
  fi
  "$ROOT/scripts/sync-tree.sh" >/dev/null 2>&1
  "$ROOT/scripts/build.sh" "$PKG" >/dev/null 2>&1
  ls -1t "$ROOT/debs/${PKG}_"*.deb 2>/dev/null | head -1
}

bench_variant() {   # $1=deb $2=port  → 输出 ops/sec 中位数
  local deb="$1" port="$2" work
  work=$(mktemp -d); dpkg-deb -x "$deb" "$work"
  "$work/usr/bin/valkey-server" --port "$port" --save '' --appendonly no \
      --daemonize yes --logfile "$work/server.log" --dir "$work" >/dev/null 2>&1
  sleep 2
  # 预热一次
  "$work/usr/bin/valkey-benchmark" -p "$port" -n 5000 -c "$CLIENTS" -t set,get -q >/dev/null 2>&1
  local vals=()
  for i in $(seq 1 "$ROUNDS"); do
    local out ops
    out=$("$work/usr/bin/valkey-benchmark" -p "$port" -n "$REQS" -c "$CLIENTS" -t set,get -q 2>/dev/null)
    # 两行结果（SET / GET），取各自 ops/sec 的平均
    ops=$(echo "$out" | grep -oE '[0-9]+(\.[0-9]+)? requests per second' | awk '{s+=$1;n++} END{if(n)printf "%d", s/n}')
    [[ -n "$ops" ]] && vals+=("$ops")
    sleep 1
  done
  "$work/usr/bin/valkey-cli" -p "$port" shutdown nosave >/dev/null 2>&1 || kill %1 2>/dev/null
  rm -rf "$work"
  (( ${#vals[@]} )) && printf '%s\n' "${vals[@]}" | sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}'
}

echo "  === ① 构建原始版 ==="; ORIG=$(build_variant orig);   echo "  $(basename "${ORIG:-失败}")"
echo "  === ② 构建补丁版 ==="; PATCHED=$(build_variant patched); echo "  $(basename "${PATCHED:-失败}")"
[[ -z "$ORIG" || -z "$PATCHED" ]] && { echo "  构建失败，退出"; exit 1; }

echo "  === ③ 压测（$REQS 请求 / $CLIENTS 并发 / $ROUNDS 轮）==="
OA=$(bench_variant "$ORIG" "$PORTA")
PA=$(bench_variant "$PATCHED" "$PORTB")
echo "  原始版: ${OA:-N/A} ops/sec"
echo "  补丁版: ${PA:-N/A} ops/sec"

{
  echo "# valkey 补丁 A/B 压测"; echo ""; echo "生成: $(date -Is)"; echo ""
  echo "补丁：\`use-system-jemalloc\`（内置 jemalloc → 系统 libjemalloc）"
  echo ""
  echo "| 版本 | 产物 | ops/sec（中位） |"
  echo "| --- | --- | --- |"
  echo "| 原始 | $(basename "$ORIG") | ${OA:-N/A} |"
  echo "| 补丁 | $(basename "$PATCHED") | ${PA:-N/A} |"
  echo ""
} > "$RESULT"

if [[ -n "$OA" && -n "$PA" ]]; then
  if (( PA * 100 > OA * 105 )); then echo "  **结论：补丁版快 $(( (PA-OA)*100/OA ))% → 保留补丁**" | tee -a "$RESULT"
  elif (( OA * 100 > PA * 105 )); then echo "  **结论：原始版快 $(( (OA-PA)*100/PA ))% → 撤补丁**" | tee -a "$RESULT"
  else echo "  **结论：差异 <5%，无显著差别 → 保留补丁（默认跟随 Arch）**" | tee -a "$RESULT"; fi
else
  echo "  **结论：压测无有效数据，需人工排查**" | tee -a "$RESULT"
fi
echo "  报告: $RESULT"
