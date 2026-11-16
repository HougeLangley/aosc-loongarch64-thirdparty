#!/usr/bin/env bash
# dep-satisfiable.sh —— 发布前的依赖可满足性检查（任务③）
#
# 检查每个第三方包的 Depends 是否能被「我方源 ∪ 官方 AOSC 源」满足。
# 任一依赖两边都没有 → 报告为 UNSATISFIABLE，需自建该依赖包并发布到第三方源。
#
# 用法：dep-satisfiable.sh [--fix]
#   --fix  把缺失的依赖名写进 state/dep-gaps.txt，供后续建包
set -uo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
DEBS="$ROOT/debs"
OUT="$ROOT/state/dep-gaps.txt"
mkdir -p "$ROOT/state"

# ① 收集「可提供方」：我方已构建 + 官方 aosc 源（含 Provides）
declare -A PROVIDES=()
add_provider() { PROVIDES["$1"]=1; }

for f in "$DEBS"/*.deb; do
    [[ -f "$f" ]] || continue
    n=$(dpkg-deb -f "$f" Package 2>/dev/null)
    [[ -n "$n" ]] && add_provider "$n"
done
OURS=${#PROVIDES[@]}
echo "  我方提供: $OURS 个包名"

# 官方 AOSC 源的包名与 Provides（来自本地 apt 索引）
if command -v apt-cache >/dev/null 2>&1; then
    while read -r p; do [[ -n "$p" ]] && add_provider "$p"; done < <(apt-cache pkgnames 2>/dev/null)
fi
echo "  加官方后: ${#PROVIDES[@]} 个包名"

# ② 逐包检查 Depends
missing_total=0; pkg_bad=0
: > "$OUT"
for f in "$DEBS"/*.deb; do
    [[ -f "$f" ]] || continue
    n=$(basename "$f" | sed 's/_.*//')
    # 只检查每包最新版
    [[ "$f" == "$(ls -1t "$DEBS/${n}"_*.deb 2>/dev/null | head -1)" ]] || continue
    deps=$(dpkg-deb -f "$f" Depends 2>/dev/null)
    [[ -z "$deps" ]] && continue
    bad=()
    # 拆 Depends：逗号分组是「或」，组内空格是「与」
    while IFS= read -r grp; do
        grp=$(echo "$grp" | sed 's/^ *//; s/ *$//')
        [[ -z "$grp" ]] && continue
        ok=0
        for alt in $(echo "$grp" | tr '|' ' '); do
            name=$(echo "$alt" | sed 's/(.*//; s/^ *//; s/ *$//')
            name=${name%:any}
            [[ -z "$name" ]] && continue
            [[ -n "${PROVIDES[$name]:-}" ]] && { ok=1; break; }
        done
        (( ok == 0 )) && bad+=("$grp")
    done < <(echo "$deps" | tr ',' '\n')
    if (( ${#bad[@]} > 0 )); then
        pkg_bad=$((pkg_bad+1)); missing_total=$((missing_total+${#bad[@]}))
        echo "  [不可满足] $n"
        for b in "${bad[@]}"; do echo "    - $b"; echo "$n|$b" >> "$OUT"; done
    fi
done

echo "  ---"
echo "  不可满足的包: $pkg_bad 个，缺失依赖项: $missing_total 处"
[[ -s "$OUT" ]] && echo "  清单: $OUT（供后续自建依赖包）"
[[ "$missing_total" -eq 0 ]]
