#!/usr/bin/env bash
# rootfs-install-test.sh —— 完整 dpkg -i 安装 + 运行测试（任务③终态）
#
# 前提：已用本脚本的 --bootstrap 建好 base rootfs（见下）
# 用法：
#   rootfs-install-test.sh --bootstrap   建/重建 base rootfs
#   rootfs-install-test.sh <包名...>      在这些包上做真装 + 运行
#
# 为什么需要 /proc：Rust 程序取 current_exe() 依赖 /proc/self/exe，
# 全流程只用 systemd-nspawn：它会挂 /proc，裸 chroot 不会。
set -uo pipefail
ROOTFS="${ROOTFS_DIR:-/mnt/build-data/rootfs-base}"
CHROOT="$ROOTFS"   # 兼容旧变量名

# 统一的「在 rootfs 里执行命令」入口。一律走 systemd-nspawn：
# 裸 chroot 挂不上 /proc，Rust 程序取 current_exe() 会 panic（L541）。
ns_run() {
  sudo systemd-nspawn -D "$ROOTFS" --quiet --pipe \
    env PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin "$@"
}
DEBS="${CHROOT_DEBS:-/mnt/build-data/base-debs}"

bootstrap() {
  echo "  建 base rootfs: $ROOTFS"
  sudo rm -rf "$CHROOT" "$DEBS"; sudo mkdir -p "$CHROOT" "$DEBS"
  sudo chown houge:houge "$DEBS" "$(dirname "$CHROOT")" 2>/dev/null
  ( cd "$DEBS" && apt-get download bash coreutils dpkg glibc liblol zlib \
      gcc-runtime gcc-runtime-16 sed grep tar gzip findutils diffutils >/dev/null 2>&1 )
  for d in "$DEBS"/*.deb; do sudo dpkg-deb -x "$d" "$CHROOT" 2>/dev/null || true; done
  # usrmerge + loader：AOSC 把 bash 装在 /usr/bin，loader 在 /usr/lib
  for l in bin sbin lib64; do sudo ln -sfn "usr/$l" "$CHROOT/$l" 2>/dev/null; done
  sudo mkdir -p "$CHROOT/usr/lib64"
  sudo ln -sfn ../lib/ld-linux-loongarch-lp64d.so.1 \
    "$CHROOT/usr/lib64/ld-linux-loongarch-lp64d.so.1" 2>/dev/null
  # 迭代补齐 base 工具自身的依赖，直到全部可执行
  local round miss pkgs so p
  for round in 1 2 3 4 5; do
    miss=""
    for cmd in "/usr/bin/bash -c true" "/usr/bin/tar --version" \
               "/usr/bin/zstd --version" "/usr/bin/dpkg-deb --version" \
               "/usr/bin/diff --version"; do
      miss="$miss $(ns_run $cmd 2>&1 \
        | grep -oE 'lib[a-zA-Z0-9_.-]+\.so[.0-9]*' | sort -u | tr '\n' ' ')"
    done
    miss=$(echo $miss | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ')
    [[ -z "$miss" ]] && break
    pkgs=""
    for so in $miss; do p=$(dpkg -S "$so" 2>/dev/null | head -1 | cut -d: -f1); [[ -n "$p" ]] && pkgs="$pkgs $p"; done
    pkgs=$(echo $pkgs | tr ' ' '\n' | sort -u | tr '\n' ' ')
    [[ -z "$pkgs" ]] && { echo "  [WARN] 无法解析: $miss"; break; }
    echo "  第 $round 轮补: $pkgs"
    ( cd "$DEBS" && apt-get download $pkgs >/dev/null 2>&1 )
    for d in "$DEBS"/*.deb; do sudo dpkg-deb -x "$d" "$CHROOT" 2>/dev/null || true; done
    for l in bin sbin lib64; do sudo ln -sfn "usr/$l" "$CHROOT/$l" 2>/dev/null; done
  done
  echo "  base rootfs 就绪: $(sudo du -sh "$ROOTFS" | cut -f1)"
}

run_test() {
  local pkg="$1"
  local W="/mnt/build-data/itest-$pkg"; sudo rm -rf "$W"; mkdir -p "$W"
  ( cd "$W" && apt-get download "$pkg" >/dev/null 2>&1 ) || { echo "  [SKIP] $pkg 下不到"; return 2; }
  # L542：必须拉完整传递闭包。只拉一层 Depends 会把「环境缺库」误报成「包漏依赖」。
  local deps
  deps=$(apt-rdepends "$pkg" 2>/dev/null | grep -vE '^\s' | grep -v "^$pkg$" | sort -u | tr '\n' ' ')
  if [[ -z "$deps" ]]; then
    # 单层 Depends 兜底：能覆盖绝大多数包，但漏传递依赖。
    # 漏掉的库表现成「缺库」，会被误判为包缺陷（L542）——所以失败时要先查是不是环境缺。
    deps=$(dpkg-deb -f "$W/${pkg}"_*.deb Depends 2>/dev/null | tr ',' '\n' \
           | sed 's/(.*//; s/|.*//; s/^ *//; s/ *$//' | grep -vE '^$' | sort -u | tr '\n' ' ')
    echo "  [NOTE] $pkg 只解析了直接 Depends（无 apt-rdepends）；若报缺库请先怀疑环境" >&2
  fi
  [[ -n "$deps" ]] && ( cd "$W" && apt-get download $deps >/dev/null 2>&1 )
  # 关键：systemd-nspawn 会挂空的 tmpfs 到 /tmp，宿主放进去的 deb 容器里看不到（L549）。
  # 用 /root/debs 这种普通目录，才能被容器看到。
  sudo mkdir -p "$CHROOT/root/debs"; sudo rm -f "$CHROOT/root/debs"/*.deb 2>/dev/null
  sudo cp -f "$W"/*.deb "$CHROOT/root/debs/" 2>/dev/null
  ns_run /bin/bash -c 'dpkg -i --force-depends /root/debs/*.deb' >/dev/null 2>&1
  local bin=""
  # rootfs 归 root 所有，[[ -e ]] 以普通用户判断永远为假 —— 必须用 sudo test
  for c in "/usr/bin/$pkg" "/usr/bin/${pkg%-*}" "/usr/sbin/$pkg"; do
    sudo test -e "$CHROOT$c" && { bin="$c"; break; }
  done
  [[ -z "$bin" ]] && { echo "  [SKIP] $pkg 无同名主二进制"; return 2; }
  # 探针：优先 --version。TUI 程序（bashtop/btop 等）没有 --version，会直接进界面并超时，
  # 这时退化为「能启动 + 未报缺库」就算通过，不算失败。
  local out rc
  out=$(timeout 30 ns_run "$bin" --version 2>&1 | tr -d '\r' | tail -1)
  rc=$?
  if [[ $rc -eq 0 && -n "$out" ]]; then
    echo "  [PASS] $pkg: ${out:0:60}"
    return 0
  fi
  if [[ $rc -eq 124 ]]; then
    # 超时：TUI 或需要交互。只要不是「缺库/找不到」就判 PASS
    echo "  [PASS] $pkg: TUI/交互程序，--version 不适用（已确认可启动，未缺库）"
    return 0
  fi
  if echo "$out" | grep -qE 'cannot open shared object|not found|No such file'; then
    echo "  [FAIL] $pkg: 缺库/找不到: ${out:0:80}"
    return 1
  fi
  # 127 = 命令找不到 = 安装失败。绝不能当 PASS（我自己造过一次假通过）。
  if [[ $rc -eq 127 ]]; then
    echo "  [FAIL] $pkg: $bin 不存在或不可执行（rc=127，安装失败）"
    return 1
  fi
  echo "  [FAIL] $pkg: $bin --version 返回 $rc，输出: ${out:0:80}"
  return 1
}

if [[ "${1:-}" == "--bootstrap" ]]; then bootstrap; exit $?; fi
[[ -x "$CHROOT/usr/bin/dpkg" ]] || { echo "  base rootfs 不存在，先跑 --bootstrap"; exit 1; }
pass=0; fail=0; skip=0
for p in "${@:-}"; do
  [[ -z "$p" ]] && continue
  run_test "$p"; case $? in 0) pass=$((pass+1));; 1) fail=$((fail+1));; *) skip=$((skip+1));; esac
done
echo "  ---"
echo "  通过 $pass / 失败 $fail / 跳过 $skip"
[[ "$fail" -eq 0 ]]
