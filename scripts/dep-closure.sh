#!/usr/bin/env bash
# dep-closure.sh —— 递归解析一个包的完整依赖闭包（替代不可用的 apt-rdepends）
set -uo pipefail
declare -A seen=(); out=()
walk() {
  local p="$1"
  [[ -n "${seen[$p]:-}" ]] && return
  seen[$p]=1
  local d
  # apt-cache depends 每行形如 "  依赖: name" / "  Depends: name" / "    name"
  while read -r d; do
    [[ -z "$d" ]] && continue
    walk "$d"
  done < <(apt-cache depends "$p" 2>/dev/null \
           | sed -nE 's/^ *[^ ]*: *//p' \
           | grep -vE '^<|^$|^[A-Za-z]+$' )
  out+=("$p")
}
walk "${1:?用法: dep-closure.sh <包名>}"
printf '%s\n' "${out[@]}" | grep -v "^$1$" | sort -u
