#!/usr/bin/env bash
# build.sh —— 单包构建执行器（编译机侧，主路径）
#
# 构建后端选择（基于实测证据）：
#   host  : 宿主机 acbs（默认，主路径）
#           - 已两次验证成功（tree 2.1.1-1、entr 5.7）
#           - 同一棵 ABBS 树、同一配方，ciel 容器内会报
#             "Could not find package"，而宿主机正常，故主路径用 host
#   ciel  : ciel BuildKit 容器（隔离更好，但对新配方不稳定，待查）
#
# 宿主机 acbs 会执行 `pm_install_all` 把构建产物装进系统（autobuild 设计如此）。
# 防护：构建前保存 dpkg 选择快照，构建后对比并报告非预期变更。
#
# 用法: build.sh <pkg> [<pkg> ...]
#   BUILD_BACKEND=host|ciel  (默认 host)
set -uo pipefail

# rustc 1.99.1 在 loongarch64 上用增量编译偶发 ICE/SIGSEGV（增量哈希路径的 bug）。
# 关闭后 bandwhich、grex 都能正常编译，代价只是每次全量编译。
export CARGO_INCREMENTAL=0

ROOT="${BUILD_ROOT:-/home/houge/build}"
TREE="${ABBS_TREE:-$ROOT/abbs/aosc-os-abbs}"
OUTPUT="${CIEL_OUTPUT:-/home/houge/OUTPUT-stable/debs}"
HOST_DEBOUT="/debs"
INSTANCE="${CIEL_INST:-main}"
BACKEND="${BUILD_BACKEND:-host}"
mkdir -p "$ROOT/logs" "$ROOT/state" "$ROOT/debs" "$ROOT/snapshots"

# 第三方构建所需的环境：Go 模块代理（国内可达）、Cargo 网络
export GOPROXY="${GOPROXY:-https://goproxy.cn,https://proxy.golang.org,direct}"
export GONOSUMDB="${GONOSUMDB:-}"
export GOTOOLCHAIN="${GOTOOLCHAIN:-local}"
export CARGO_NET_GIT_FETCH_WITH_CLI="${CARGO_NET_GIT_FETCH_WITH_CLI:-true}"

FAILN=0
status_set() {
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" > "$ROOT/state/$PKG.status"
  # L607：退出码必须反映失败。调用方（auto-cycle/lane）只看 rc——
  # 这里漏掉，失败的包会被当成功，旧 deb 会被再次发布。
  [[ "$1" == "fail" ]] && FAILN=$((FAILN+1)) || true
  return 0
}

snapshot_dpkg() { dpkg-query -W -f '${Package}\t${Version}\t${db:Status-Abbrev}\n' 2>/dev/null | sort; }

# script/sudo/pexpect 可能让 Autobuild 另建 session；外层 timeout 不一定能回收它。
# 只按 ACBS 自己日志中的临时目录定位进程组，禁止 pgrep/pkill 命令行自匹配。
ACTIVE_LOG=""
cleanup_active_build() {
  [[ -n "$ACTIVE_LOG" ]] || return 0
  sudo -n python3 "$ROOT/scripts/cleanup-acbs-tree.py" "$ACTIVE_LOG" "$PKG"
}
on_build_exit() {
  local rc=$?
  trap - EXIT HUP INT TERM
  if ! cleanup_active_build; then
    echo "  [fail] ACBS 进程树清理失败" >&2
    [[ $rc -ne 0 ]] || rc=1
  fi
  exit "$rc"
}
trap on_build_exit EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

for PKG in "$@"; do
  LOG="$ROOT/logs/$PKG.log"
  START_TS=$(date +%s)
  START_ISO=$(date -Is)
  echo "=============================================================="
  echo "[$(date +%H:%M:%S)] BUILD $PKG  (backend=$BACKEND)"
  echo "=============================================================="
  status_set running "$START_ISO" 0 "" ""

  [[ -d "$TREE" ]] || { echo "  [fail] 构建树不存在: $TREE"; status_set fail "$START_ISO" 0 "" "no-tree"; continue; }
  PKGDIR_FOUND=$(find "$TREE" -mindepth 2 -maxdepth 2 -type d -name "$PKG" 2>/dev/null | head -1)
  if [[ -z "$PKGDIR_FOUND" ]]; then
    echo "  [fail] 树中找不到包: $PKG"
    status_set fail "$START_ISO" 0 "" "not-in-tree"
    continue
  fi
  # 只建我们自己同步进去的包（带 .thirdparty 标记）。
  # 否则 ACBS 会按包名解析到官方同名配方，构建"成功"、闸门通过，
  # 但产物是别人的——这种无声失败极难发现（教训 L173/L172）。
  if [[ ! -f "$PKGDIR_FOUND/.thirdparty" ]]; then
    echo "  [fail] $PKG 不是第三方包（$PKGDIR_FOUND 无 .thirdparty 标记）——拒绝构建官方配方"
    status_set fail "$START_ISO" 0 "" "not-thirdparty"
    continue
  fi

  # ACBS 通过 git 枚举包：未跟踪的包会被判定为 "Could not find package"
  if [[ -n "$(git -C "$TREE" status --porcelain 2>/dev/null)" ]]; then
    echo "  [git] 提交树变更"
    git -C "$TREE" add -A >/dev/null 2>&1
    git -C "$TREE" -c user.email="repo@localhost" -c user.name="AOSC Third-party Build" \
      commit -q -m "thirdparty: sync before building $PKG" >/dev/null 2>&1 \
      || echo "  [git][warn] 提交失败"
  fi

  # ---- 系统污染快照 ----
  SNAP_BEFORE="$ROOT/snapshots/$PKG.before.tsv"
  SNAP_AFTER="$ROOT/snapshots/$PKG.after.tsv"
  snapshot_dpkg > "$SNAP_BEFORE"

  # ---- 构建 ----
  ACTIVE_LOG="$LOG"
  if [[ "$BACKEND" == "ciel" ]]; then
    # ciel 需要 TTY：用 script 提供 pty，避免 pexpect/termios 失败
    ( cd "$TREE" && script -qec "sudo -n ciel build -i $INSTANCE $PKG" /dev/null ) > "$LOG" 2>&1
  else
    # 宿主机 acbs 同样需要 TTY（pexpect interact）
    ( cd "$TREE" && script -qec "sudo -n acbs-build -t default $PKG" /dev/null ) > "$LOG" 2>&1
  fi
  RC=$?
  if ! cleanup_active_build; then
    echo "  [fail] ACBS 进程树清理失败"
    RC=1
  fi
  ACTIVE_LOG=""
  DUR=$(( $(date +%s) - START_TS ))
  snapshot_dpkg > "$SNAP_AFTER"

  # ---- 污染报告 ----
  NEWPKGS=$(comm -13 "$SNAP_BEFORE" "$SNAP_AFTER" | awk -F'\t' '{print $1}' | tr '\n' ' ')
  CHANGED=$(join -t$'\t' -j1 "$SNAP_BEFORE" "$SNAP_AFTER" 2>/dev/null \
            | awk -F'\t' '$2!=$4 || $3!=$5 {print $1}' | tr '\n' ' ')
  [[ -n "${NEWPKGS// /}" ]] && echo "  [dpkg] 新增包: $NEWPKGS"
  [[ -n "${CHANGED// /}" ]] && echo "  [dpkg] 版本/状态变更: $CHANGED"

  if [[ $RC -ne 0 ]] || ! grep -q "ACBS Build Successful" "$LOG" 2>/dev/null; then
    echo "  [fail] 构建失败 (rc=$RC, ${DUR}s)  日志: $LOG"
    ERR=$(sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$LOG" 2>/dev/null \
          | grep -m1 -E "ERROR|error:|abdie|E[0-9]{3}|Could not find|nspawn" | head -c 300)
    echo "  首条错误: ${ERR:-<未匹配到>}"
    status_set fail "$START_ISO" "$DUR" "" "$(echo "$ERR" | tr '\t\n' '  ')"
    continue
  fi
  echo "  [ok] 构建成功 (${DUR}s)"

  # ---- 产物定位 ----
  # 宿主机 acbs -> /debs/<首字母>/<pkg>_<ver>-<rel>_<arch>.deb
  # ciel       -> $OUTPUT/<首字母>/...
  mapfile -t DEBS < <(
    find -L /debs -name "${PKG}_*_loongarch64.deb" -newermt "@$((START_TS-10))" 2>/dev/null
    find -L "$OUTPUT" -name "${PKG}_*_loongarch64.deb" -newermt "@$((START_TS-10))" 2>/dev/null
    find -L /debs -name "${PKG}_*_all.deb" -newermt "@$((START_TS-10))" 2>/dev/null
    find -L /debs -name "${PKG}_*_noarch.deb" -newermt "@$((START_TS-10))" 2>/dev/null
    find -L "$OUTPUT" -name "${PKG}_*_all.deb" -newermt "@$((START_TS-10))" 2>/dev/null
    find -L "$OUTPUT" -name "${PKG}_*_noarch.deb" -newermt "@$((START_TS-10))" 2>/dev/null
  )
  if [[ ${#DEBS[@]} -eq 0 ]]; then
    echo "  [fail] 构建成功但找不到 .deb 产物"
    status_set fail "$START_ISO" "$DUR" "" "no-deb"
    continue
  fi

  FIRST_DEB=""
  for D in "${DEBS[@]}"; do
    # autobuild4 对 ABHOST=noarch 的包：control 写 Architecture: all，但文件名用 _noarch。
    # 发布脚本按 control 判定（接受），但要求文件名 <pkg>_<ver>_<arch>.deb 一致，
    # 因此这里统一归一化为 _all.deb。
    B="$(basename "$D")"
    if [[ "$B" == *_noarch.deb ]]; then
      B="${B%_noarch.deb}_all.deb"
    fi
    cp -f "$D" "$ROOT/debs/$B"
    echo "  产物: $B"
    # L431：以前取 glob 第一个，扫到旧版会让闸门冤枉新构建。改为取最新。
    FIRST_DEB="$(ls -1t "$ROOT/debs/$B" 2>/dev/null | head -1)"
  done

  # ---- 自检（包自身一致性）----
  SELFCHECK="$ROOT/logs/${PKG}.selfcheck.txt"
  if "$ROOT/scripts/selfcheck.sh" "$FIRST_DEB" > "$SELFCHECK" 2>&1; then
    echo "  自检: PASS -> $SELFCHECK"
    SC="PASS"
  else
    echo "  自检: FAIL -> $SELFCHECK"
    SC="FAIL"
  fi

  # ---- 对等性闸门（同名覆盖官方包时必过）----
  # 教训：libpng 只抄当前 HEAD 配方导致静默丢失 APNG 19 个导出符号，
  # selfcheck 只看包自身、看不出功能回退。覆盖型包必须与官方件比对。
  PARITY="$ROOT/logs/${PKG}.parity.txt"
  # 传入 --pkg-src，让闸门能读到配方里的 tests/parity-allow（预期差异申明）
  _PSRC=$(find "$TREE" -mindepth 2 -maxdepth 2 -type d -name "$PKG" 2>/dev/null | head -1)
  "$ROOT/scripts/parity-check.sh" "$FIRST_DEB" ${_PSRC:+--pkg-src "$_PSRC"} > "$PARITY" 2>&1
  PRC=$?
  if [[ $PRC -eq 0 ]]; then
    if grep -q '属新增型包' "$PARITY" 2>/dev/null; then
      echo "  对等性: SKIP（官方无同名包）-> $PARITY"
      PC="SKIP"
    else
      echo "  对等性: PASS -> $PARITY"
      PC="PASS"
    fi
  else
    echo "  对等性: FAIL（功能回退，禁止发布）-> $PARITY"
    grep -E '^\s+\[FAIL\]' "$PARITY" 2>/dev/null | head -3 | sed 's/^/  /'
    PC="FAIL"
  fi

  # ---- T2 功能冒烟闸门（自动探测 + Python 依赖对账）----
  # 教训：yamllint 自检与对等性全 PASS，但 --version 直接 ModuleNotFoundError；
  # 解释型语言的 import 依赖不产生 ELF NEEDED，静态闸门查不出，必须真跑一次。
  SMOKE="$ROOT/logs/${PKG}.smoke.txt"
  PKGSRC=$(find "$TREE" -mindepth 2 -maxdepth 2 -type d -name "$PKG" 2>/dev/null | head -1)
  "$ROOT/scripts/smoke-test.sh" "$FIRST_DEB" ${PKGSRC:+--pkg-src "$PKGSRC"} > "$SMOKE" 2>&1
  SMRC=$?
  if [[ $SMRC -eq 0 ]]; then
    echo "  冒烟: PASS -> $SMOKE"
    SM="PASS"
  else
    echo "  冒烟: FAIL -> $SMOKE"
    grep -E '^\s+\[FAIL\]' "$SMOKE" 2>/dev/null | head -3 | sed 's/^/  /'
    SM="FAIL"
  fi

  # ---- T2.5 载荷洁净度闸门 ----
  # 教训 L18 出现三次（fclones/watchexec/git-branchless 都把 workspace 的
  # 测试辅助程序装进了 /usr/bin），人工看 dpkg-deb -c 不可靠，做成闸门。
  PAYLOAD="$ROOT/logs/${PKG}.payload.txt"
  "$ROOT/scripts/payload-check.sh" "$FIRST_DEB" > "$PAYLOAD" 2>&1
  PLRC=$?
  if [[ $PLRC -eq 0 ]]; then
    echo "  载荷: PASS -> $PAYLOAD"
    PL="PASS"
  else
    echo "  载荷: FAIL -> $PAYLOAD"
    grep -E '^\s+\[FAIL\]' "$PAYLOAD" 2>/dev/null | head -3 | sed 's/^/  /'
    PL="FAIL"
  fi

  if [[ "$SC" == "PASS" && "$PC" != "FAIL" && "$SM" == "PASS" && "$PL" == "PASS" ]]; then
    # 版本占位符检测（教训 L240/L241）：不再猜 -X 变量位置，改成事后验证。
    # 二进制在 /usr/bin 跑一次 --version/version，输出含占位符则 WARN。
    _warn=0
    for _b in $(find "$PKGDIR_FOUND" -maxdepth 3 -path '*/usr/bin/*' -type f 2>/dev/null | head -6); do
        _out=$(_b --version 2>/dev/null | head -1; _b version 2>/dev/null | head -1)
        if printf '%s' "$_out" | grep -qiE '(^|[^a-z])(dev|unversioned|unknown-version|v0\.0\.0)([^a-z]|$)'; then
            echo "  [warn] $(basename "$_b") 版本疑似未注入：$(printf '%s' "$_out" | head -1 | cut -c1-70)"
            _warn=$((_warn+1))
        fi
    done
    if [[ "$_warn" -gt 0 ]]; then
        echo "  [warn] $_warn 个二进制版本未注入——给配方加 GO_LDFLAGS=("-X <变量>=\$PKGVER")"
    fi

    # 产物版本一致性（教训 L208）：状态 ok 只说明「某次」成功过。
    # 若队列里有同名包的旧构建先完成，ok 可能来自旧产物。
    # 必须核对产物文件名里的 VER-REL 与当前 spec 一致，才算「这次」建成功。
    _specver=$(grep -m1 '^VER=' "$PKGDIR_FOUND/spec" 2>/dev/null | cut -d= -f2-)
    _specrel=$(grep -m1 '^REL=' "$PKGDIR_FOUND/spec" 2>/dev/null | cut -d= -f2-)
    _expect="$(basename "$FIRST_DEB" | sed -E "s/^.*_([^_]+)_[^_]+\\.deb$/\1/")"
    if [[ -n "$_specver" && "$_expect" != "${_specver}-${_specrel:-0}" ]]; then
        echo "  [fail] 产物版本不符：产物=$_expect  配方=${_specver}-${_specrel:-0}"
        echo "         可能是旧构建的产物，或 ACBS 解析到了别的配方"
        status_set fail "$START_ISO" "$DUR" "$(basename "$FIRST_DEB")" "version=mismatch"
        continue
    fi
    status_set ok "$START_ISO" "$DUR" "$(basename "$FIRST_DEB")" "backend=$BACKEND selfcheck=$SC parity=$PC smoke=$SM payload=$PL"
  else
    status_set fail "$START_ISO" "$DUR" "$(basename "$FIRST_DEB")" "selfcheck=$SC parity=$PC smoke=$SM payload=$PL"
  fi
done
exit $(( FAILN > 0 ? 1 : 0 ))
