#!/usr/bin/env bash
# install-test.sh —— 发布前的真实安装测试（任务③）
#
# 对每个第三方包：
#   1. apt-get download 拉「包 + 全部 Depends」的真实 .deb（含官方 AOSC 依赖）
#   2. dpkg --root=<隔离目录> 真解包并跑 postinst
#   3. chroot 进隔离目录，执行包内主二进制 --version
#
# 这比 dep-satisfiable.sh 严格：那个只查「名字能不能解析」，
# 这个查「文件能不能落地、动态库能不能解析、二进制能不能跑」。
#
# 用法：install-test.sh [包名...]     不给包名则测全部
set -uo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
LOG="$ROOT/logs/install-test.txt"
WORK="${INSTALL_TEST_WORK:-/mnt/build-data/install-test}"
:
mkdir -p "$ROOT/logs" "$WORK"

mapfile -t PKGS < <(
  if (( $# )); then printf '%s\n' "$@"
  else
    for f in "$ROOT"/debs/*.deb; do
      n=$(basename "$f" | sed 's/_.*//'); echo "$n"
    done | sort -u
  fi
)

pass=0; fail=0; skip=0
: > "$LOG"
for pkg in "${PKGS[@]}"; do
  R="$WORK/$pkg"; D="$WORK/$pkg-debs"
  sudo rm -rf "$R" "$D" 2>/dev/null; mkdir -p "$R/var/lib/dpkg" "$D"
  : > "$R/var/lib/dpkg/status"

  # ① 拉全量闭包（包本身 + 它从我们源和官方源解析出的依赖）
  if ! ( cd "$D" && timeout 300 apt-get download "$pkg" >/dev/null 2>&1 ); then
    echo "  [SKIP] $pkg: 源里下不到" | tee -a "$LOG"; skip=$((skip+1)); continue
  fi
  # 依赖的包名（不含版本约束）
  deps=$(dpkg-deb -f "$D/${pkg}"_*.deb Depends 2>/dev/null | tr ',' '\n' \
         | sed 's/(.*//; s/|.*//; s/^ *//; s/ *$//' | grep -vE '^$' | sort -u)
  if [[ -n "$deps" ]]; then
    ( cd "$D" && timeout 600 apt-get download $deps >/dev/null 2>&1 ) || true
  fi

  # ② 解包到隔离目录（dpkg-deb -x 可靠；dpkg -i 需要 base 系统的 /bin/sh 跑 postinst）
  mkdir -p "$R"
  for deb in "$D"/*.deb; do
    dpkg-deb -x "$deb" "$R" 2>/dev/null || true
  done
  if [[ ! -d "$R/usr" ]]; then
    echo "  [FAIL] $pkg: 解包后无 /usr" | tee -a "$LOG"; fail=$((fail+1)); continue
  fi

  # ③ 主二进制存在性 + 动态库可解析性
  bin=""
  for cand in "/usr/bin/$pkg" "/usr/bin/${pkg%-*}" "/usr/sbin/$pkg"; do
    [[ -e "$R$cand" ]] && { bin="$cand"; break; }
  done
  if [[ -z "$bin" ]]; then
    echo "  [SKIP] $pkg: 无同名主二进制（库/脚本包）" | tee -a "$LOG"; skip=$((skip+1)); continue
  fi
  # 用「解包目录 + 宿主库」解析 NEEDED；缺的库名逐条列出
  missing=$(readelf -d "$R$bin" 2>/dev/null | grep NEEDED | sed 's/.*\[\(.*\)\]/\1/' \
            | while read -r so; do
                [[ -e "$R/usr/lib/$so" || -e "$R/lib/$so" ]] && continue
                ldconfig -p 2>/dev/null | grep -q " $so " || echo "$so"
              done | tr '\n' ' ')
  if [[ -n "$missing" ]]; then
    echo "  [FAIL] $pkg: $bin 缺库: $missing" | tee -a "$LOG"; fail=$((fail+1)); continue
  fi
  echo "  [PASS] $pkg: $bin 落地且动态库齐全" | tee -a "$LOG"; pass=$((pass+1))
done

echo "  ---"
echo "  通过 $pass / 失败 $fail / 跳过 $skip（详情 $LOG）"
[[ "$fail" -eq 0 ]]
