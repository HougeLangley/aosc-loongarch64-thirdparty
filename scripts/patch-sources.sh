#!/usr/bin/env bash
# patch-sources.sh —— 汇总 Arch 与 AOSC 两发行版对我方各包的补丁（任务⑤第 2 条）
#
# 对每个第三方包：
#   AOSC 侧：读本地 ABBS 克隆的 official 树 autobuild/patches/
#   Arch 侧：查 gitlab.archlinux.org 的 packaging/packages/<pkg> 仓库文件列表
# 输出三方对照：我们已有 / 官方有 / Arch 有，便于决定是否采纳。
set -uo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
TR="$ROOT/tree/aosc-loongarch64-thirdparty/packages"
AOSC="$ROOT/abbs/aosc-os-abbs"
OUT="$ROOT/reports/patch-sources.md"
mkdir -p "$ROOT/reports"
ARCH_API="https://gitlab.archlinux.org/api/v4/projects/archlinux%2Fpackaging%2Fpackages%2F"

echo "# 补丁来源对照（Arch / AOSC / 我方）" > "$OUT"
echo "" >> "$OUT"
echo "生成: $(date -Is)" >> "$OUT"
echo "" >> "$OUT"
echo "| 包 | 我方 | AOSC | Arch | 备注 |" >> "$OUT"
echo "| --- | --- | --- | --- | --- |" >> "$OUT"

gap=0; checked=0
for d in "$TR"/*/*/; do
  p=$(basename "$d"); checked=$((checked+1))
  ours=$(find "$d/autobuild/patches" -type f -name '*.patch' 2>/dev/null | wc -l)

  off=$(find "$AOSC" -maxdepth 2 -type d -name "$p" 2>/dev/null | head -1)
  aosc=0
  [[ -n "$off" ]] && aosc=$(find "$off/autobuild/patches" -type f 2>/dev/null | wc -l)

  # Arch：拿文件列表里 .patch 的个数（无仓库/无补丁都是 0）
  arch=$(timeout 20 curl -s "$ARCH_API$p/repository/tree?per_page=100" 2>/dev/null \
         | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(sum(1 for f in d if isinstance(f,dict) and f.get('name','').endswith('.patch')) if isinstance(d,list) else 0)
except Exception:
    print(0)
" 2>/dev/null || echo 0)

  note=""
  if (( arch > ours )); then note="Arch 有 $((arch-ours)) 个未采纳"; gap=$((gap+1)); fi
  if (( ours > 0 || aosc > 0 || arch > 0 )); then
    echo "| \`$p\` | $ours | $aosc | $arch | $note |" >> "$OUT"
  fi
done

echo "" >> "$OUT"
echo "检查 $checked 个包；Arch 侧有未采纳补丁的 $gap 个。" >> "$OUT"
echo "  检查 $checked 个包；Arch 侧有未采纳补丁的 $gap 个"
echo "  报告: $OUT"
