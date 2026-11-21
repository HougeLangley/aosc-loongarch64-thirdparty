#!/usr/bin/env bash
# smoke-test.sh —— T2 功能冒烟闸门（自动探测版）
#
# 背景（教训来源）：
#   yamllint 1.38.0-1 构建成功、selfcheck 7 项 PASS、parity SKIP，
#   但 `yamllint --version` 直接 ModuleNotFoundError: pathspec。
#   Python 依赖靠 import，不产生 ELF NEEDED，所以 selfcheck / parity
#   这两道"看结构"的闸门永远发现不了；只有真的执行一次才知道。
#
# 本脚本做的事：
#   1. 解开 deb，列出 usr/bin、usr/sbin、usr/libexec 下的可执行文件
#   2. 逐个尝试 --version / -V / --help / -h / 空参数
#   3. 在输出里扫描运行时错误特征（Traceback / ModuleNotFoundError /
#      cannot open shared object / Illegal instruction / Segmentation fault …）
#   4. 若是解释型脚本，额外检查 shebang 解释器是否存在
#   5. 若配方目录下有 tests/smoke.sh，一并执行（包专属验收）
#
# 在**宿主机的临时 chroot 视图**外执行（直接跑解包出来的二进制），
# 因此只能验证"能不能起得来"，不能验证需要独占资源的服务；
# 服务类包的深度验证仍应在测试机做。
#
# 用法:
#   smoke-test.sh <deb> [--pkg-src DIR]
#
# 退出码: 0=PASS  1=FAIL  2=用法错误
set -uo pipefail

DEB=""
PKGSRC=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pkg-src) PKGSRC="$2"; shift 2 ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    -*) echo "未知选项: $1" >&2; exit 2 ;;
    *)  DEB="$1"; shift ;;
  esac
done

[[ -n "$DEB" && -f "$DEB" ]] || { echo "找不到 deb: ${DEB:-<空>}" >&2; exit 2; }

PKG=$(dpkg-deb -f "$DEB" Package)
VER=$(dpkg-deb -f "$DEB" Version)
D="$(mktemp -d /tmp/smoke.XXXXXX)"
trap 'rm -rf "$D"' EXIT
dpkg-deb -x "$DEB" "$D/root" 2>/dev/null || { echo "  [FAIL] 解包失败"; exit 1; }

FAIL=0
pass() { printf '  [PASS] %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; FAIL=$((FAIL+1)); }

# 运行时错误特征
# 只收"明确的运行时失败"特征。
# 注意不要放通用的 "No such file or directory"：很多工具（如 lhasa 装的 lha）
# 会把 --version 当成文件名处理，回一句 "No such file or directory"，
# 那是正常的参数不适用，不是包坏了。
ERRPAT='Traceback \(most recent call last\)|ModuleNotFoundError|ImportError:|error while loading shared libraries|cannot open shared object file|Illegal instruction|Segmentation fault|bad interpreter|command not found'

echo "=============================================================="
echo " T2 功能冒烟"
echo " 包:   $PKG $VER"
echo " 文件: $(basename "$DEB")"
echo " 时间: $(date -Is)"
echo "=============================================================="

# ---------- 1. 收集可执行文件 ----------
mapfile -t BINS < <(
  find "$D/root"/usr/bin "$D/root"/usr/sbin "$D/root"/usr/libexec \
       -maxdepth 1 -type f -perm -u+x 2>/dev/null | sort
)
# 排除明显的开发/测试辅助文件（命名特征）
FILTERED=()
for b in "${BINS[@]:-}"; do
  [[ -n "$b" ]] || continue
  base=$(basename "$b")
  case "$base" in
    *gen-test*|*test-*|*-test|*_test) warn "跳过疑似测试辅助: $base"; continue ;;
  esac
  FILTERED+=("$b")
done
BINS=("${FILTERED[@]:-}")

if [[ ${#BINS[@]} -eq 0 ]]; then
  warn "包内没有可执行文件（纯库/数据/脚本包），跳过二进制冒烟"
else
  echo
  echo "[1/4] 可执行文件探测（共 ${#BINS[@]} 个）"
  for b in "${BINS[@]}"; do
    base=$(basename "$b")
    # shebang 解释器存在性（L22：有些包装的是脚本）
    if head -c2 "$b" 2>/dev/null | grep -q '#!'; then
      interp=$(head -1 "$b" | sed 's/^#!//' | awk '{print $1}')
      if [[ -x "$interp" ]]; then
        pass "$base: shebang 解释器存在 ($interp)"
      else
        fail "$base: shebang 解释器不存在 ($interp)"
        continue
      fi
    fi

    got=""
    for flag in --version -V --help -h ""; do
      # 注意：不能用 out=$(timeout 8 ...) —— timeout 只杀直接子进程，
      # 若程序再 fork（如 TUI 程序、shell 脚本），孙进程会成为孤儿并继续持有
      # stdout 管道，导致命令替换永远不返回（bashtop 就因此挂死 8 分钟）。
      # 改为重定向到文件：立刻返回，不依赖管道关闭。
      _of="$D/out.$base.$$"
      ( cd "$D/root" && timeout -k 2 8 env LD_LIBRARY_PATH="$D/root/usr/lib" \
              ./usr/bin/"$base" $flag </dev/null >"$_of" 2>&1 )
      rc=$?
      out=$(cat "$_of" 2>/dev/null; rm -f "$_of")
      # 命中错误特征 → 立即判失败
      if echo "$out" | grep -qE "$ERRPAT"; then
        fail "$base $flag: 运行时错误"
        echo "$out" | grep -E "$ERRPAT" | head -3 | sed 's/^/         /'
        got="FAIL"
        break
      fi
      # 有正常输出或退出码为 0 → 认为能起来
      if [[ -n "$out" ]] || [[ $rc -eq 0 ]]; then
        got="ok:$flag"
        break
      fi
    done
    case "$got" in
      FAIL) ;;
      ok:*) pass "$base: 可执行（探测参数 '${got#ok:}'）" ;;
      *)    warn "$base: 所有探测参数均无输出（可能是需要子命令的工具）" ;;
    esac
  done
fi

# ---------- 2. 共享库可解析性 ----------
echo
echo "[2/4] 共享库可解析性"
NELF=0
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  NELF=$((NELF+1))
  if ldd "$f" 2>/dev/null | grep -q 'not found'; then
    fail "$(basename "$f"): 有未解析的共享库"
  fi
done < <(find "$D/root" -type f \( -name '*.so' -o -name '*.so.*' -o -perm -u+x \) 2>/dev/null | head -200)
[[ "$NELF" -eq 0 ]] && warn "无 ELF 文件" || pass "检查了 $NELF 个 ELF 的 ldd 结果"

# ---------- 3. Python 依赖对账（Requires-Dist vs Depends）----------
echo
echo "[3/4] Python 依赖对账"
# 解释型语言的 import 依赖不产生 ELF NEEDED，selfcheck / parity 查不出。
# 这里读 wheel 元数据里的 Requires-Dist，与 deb control 的 Depends 对账，
# 专门抓"PKGDEP 漏写运行时依赖"这一类（yamllint 就是这样漏的）。
DEPENDS_LINE=$(dpkg-deb -f "$DEB" Depends 2>/dev/null | tr ',' '\n' | tr -d ' ' | cut -d'(' -f1 | sort -u)
mapfile -t METAS < <(find "$D/root" -name METADATA -path '*.dist-info*' 2>/dev/null)
if [[ ${#METAS[@]} -eq 0 ]]; then
  echo "  （非 Python 包，跳过）"
else
  PYFAIL=0
  for m in "${METAS[@]}"; do
    # 只取硬依赖：跳过带 extra == 标记的可选依赖
    while IFS= read -r req; do
      [[ -n "$req" ]] || continue
      name=$(echo "$req" | sed -E 's/^[[:space:]]*//; s/[[:space:]].*//; s/[<>=!~;(].*//' | tr 'A-Z' 'a-z')
      [[ -z "$name" ]] && continue
      # PyPI 名 -> AOSC 包名的常见归一：连字符/下划线都当连字符
      aosc=$(echo "$name" | tr '_' '-')
      # 已知的 PyPI 名与 AOSC 包名不一致的情况（按需补充）
      case "$aosc" in
          python-dateutil) aosc=dateutil ;;
          pyyaml)          aosc=pyyaml ;;
          pillow)          aosc=pillow ;;
          beautifulsoup4)  aosc=beautifulsoup4 ;;
      esac
      if echo "$DEPENDS_LINE" | grep -qx -e "$aosc" -e "$name"; then
        pass "Requires-Dist $name 已在 Depends 中"
      else
        fail "Requires-Dist $name 未出现在 Depends 里（PKGDEP 漏写）"
        PYFAIL=$((PYFAIL+1))
      fi
    # 只对「无环境标记」的依赖做对账：带 ; 的是条件依赖
    # （extra ==、sys_platform、python_version…），要求它们进 PKGDEP 是错的——
    # windows-curses 在 Linux 上永远不需要，importlib_resources 在 Python 3.9+ 已被 stdlib 取代。
    done < <(grep -E '^Requires-Dist:' "$m" 2>/dev/null |
             grep -v ';' |
             sed 's/^Requires-Dist:[[:space:]]*//')
  done
  [[ "$PYFAIL" -eq 0 ]] && pass "Python 硬依赖已与 Depends 对齐"
fi

# ---------- 3.5 版本一致性 ----------
echo
echo "[3.5/4] 版本一致性"
# 教训来源：golangci-lint 打出 (devel)、vegeta 打出空值——四闸门全绿，
# 但用户看不到版本信息。这类缺陷只有跑一次 --version 才能发现，
# 而"跑一次并比对版本号"完全可以自动化。
PKGVER=$(dpkg-deb -f "$DEB" Version | sed 's/-[0-9]*$//')
VERHIT=0
if [[ ${#BINS[@]} -gt 0 && -n "$PKGVER" ]]; then
    for b in "${BINS[@]}"; do
        base=$(basename "$b")
        # 同前：用文件重定向，避免 TUI 程序 fork 后孤儿进程持有管道导致挂死；
        # 加 -k：bashtop 这类程序会忽略 SIGTERM，必须补 SIGKILL。
        _of="$D/ver.$base.$$"
        ( cd "$D/root" && timeout -k 2 8 env LD_LIBRARY_PATH="$D/root/usr/lib" \
                ./usr/bin/"$base" --version </dev/null >"$_of" 2>&1 ) || true
        out=$(cat "$_of" 2>/dev/null; rm -f "$_of")
        [[ -n "$out" ]] || continue
        VERHIT=$((VERHIT+1))
        if echo "$out" | grep -qF "$PKGVER"; then
            pass "$base: 版本输出含 $PKGVER"
        else
            # 只 WARN：部分工具版本号格式不同（如 staticcheck 显示 2026.2.2），
            # 也可能是它根本不印版本；但不能因此放过 (devel)/空值这种情况。
            # 注意：不能用 grep '^\s*$' 判"空值"——多行输出里只要有一个空行就会命中，
            # batgrep 那种 "batgrep 2020.04.08" 会被误判成未注入。
            # 正确做法：先把所有空白/换行去掉，再看整体是否为空。
            _trim="${out//[$'\n'$'\t'$' ']/}"
            if echo "$out" | grep -qiE '\(devel\)|version:[[:space:]]*$|version:[[:space:]]*[[:cntrl:]]*$' || [[ -z "$_trim" ]]; then
                fail "$base: 版本未正确注入（输出含 (devel) 或整体为空）"
            else
                _seen=$(echo "$out" | grep -oE '[0-9]+(\.[0-9]+)+([.-][0-9A-Za-z]+)*' | head -1)
                if [[ -n "$_seen" ]]; then
                    fail "$base: 实际版本 $_seen 与包版本 $PKGVER 不一致"
                else
                    warn "$base: 版本输出未包含 $PKGVER，需人工确认"
                fi
            fi
        fi
    done
fi
[[ "$VERHIT" -eq 0 ]] && echo "  （没有可执行文件或都不支持 --version，跳过）"

# ---------- 4. 包专属冒烟（若配方提供） ----------
echo
echo "[4/4] 包专属冒烟（tests/smoke.sh）"
if [[ -n "$PKGSRC" && -f "$PKGSRC/tests/smoke.sh" ]]; then
  if ( cd "$D/root" && bash "$PKGSRC/tests/smoke.sh" ); then
    pass "tests/smoke.sh 通过"
  else
    fail "tests/smoke.sh 失败"
  fi
else
  echo "  （配方未提供 tests/smoke.sh，使用自动探测结果）"
fi

# ---------- 汇总 ----------
echo
echo "=============================================================="
if [[ "$FAIL" -eq 0 ]]; then
  echo " 冒烟结果: PASS"
  exit 0
else
  echo " 冒烟结果: FAIL（$FAIL 项）"
  echo "   提示：常见根因是 PKGDEP 漏写运行时依赖（尤其解释型语言的 import 依赖），"
  echo "        或二进制名字与包名不同导致探测参数不适用。"
  exit 1
fi
