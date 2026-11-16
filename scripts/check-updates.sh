#!/usr/bin/env bash
# check-updates.sh —— 定时检查上游更新并自动入队构建（任务①的闭环）
#
# 流程：nvchecker 查最新 tag → 与配方 VER 比对 → 更新的自动 bump + 入队
# 依赖：nvchecker（~/.local/bin）、scripts/nvchecker-gen.py、scripts/lane.sh
set -uo pipefail
ROOT="${BUILD_ROOT:-$HOME/build}"
TREE="$ROOT/tree/aosc-loongarch64-thirdparty/packages"
STATE="$ROOT/state/nvchecker.json"
REPORT="$ROOT/logs/updates.log"
PATH="$HOME/.local/bin:$PATH"
export PATH
cd "$ROOT" || exit 1
mkdir -p "$ROOT/state" "$ROOT/logs"

APPLY="${1:-}"   # 传 --apply 才真的 bump+入队（默认只报告）
[[ "$APPLY" == "--apply" ]] && export NV_APPLY=1

echo "[$(date -Is)] 1/3 生成配置" | tee -a "$REPORT"
python3 scripts/nvchecker-gen.py > "$ROOT/nvchecker.toml" 2>/dev/null || { echo "  生成失败" | tee -a "$REPORT"; exit 1; }

echo "[$(date -Is)] 2/3 查询上游" | tee -a "$REPORT"
# v2.22 无状态文件，用 json 日志捕获 "updated to X"（教训 L513）
timeout 1800 nvchecker -c "$ROOT/nvchecker.toml" --logger json --json-log-fd 3 \
    3>"$STATE.raw" 2>>"$REPORT" || echo "  nvchecker 有失败项（见 $REPORT）" | tee -a "$REPORT"
python3 - "$STATE.raw" "$STATE" <<'PY2'
import sys, json, pathlib
raw, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
ver = {}
for line in raw.read_text(errors='replace').splitlines():
    try: d = json.loads(line)
    except Exception: continue
    ev = d.get('event', '')
    v = d.get('version')
    # L513：事件是 "updated"，版本在独立的 "version" 字段里，不在 event 文本中
    if ev == 'updated' and v:
        ver[d.get('name')] = str(v)
out.write_text(json.dumps(ver, indent=1))
print(f"  捕获 {len(ver)} 个包的版本")
PY2

echo "[$(date -Is)] 3/3 比对配方" | tee -a "$REPORT"
python3 - "$TREE" "$STATE" <<'PY'
import sys, json, pathlib, re
tree, statefile = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
if not statefile.exists():
    print("  无状态文件，跳过比对"); sys.exit(0)
try:
    state = json.load(open(statefile))
except Exception as e:
    print(f"  状态文件解析失败: {e}"); sys.exit(0)

updates = []
for spec in sorted(tree.glob('*/*/spec')):
    name = spec.parent.name
    st = state.get(name)
    if not st: continue
    latest = st.get('version') if isinstance(st, dict) else st
    if not latest: continue
    latest = str(latest).lstrip('v')
    cur = ''
    for line in spec.read_text(errors='replace').splitlines():
        if line.startswith('VER='): cur = line[4:].strip().strip('"'); break
    if not cur: continue
    # 只在两者都是「纯数字点分」时比较，其余判为不可比（教训 L414）
    if not (re.fullmatch(r'[\d.]+', cur) and re.fullmatch(r'[\d.]+', latest)):
        continue
    def key(v): return [int(x) if x.isdigit() else 0 for x in v.split('.')]
    if key(latest) > key(cur):
        updates.append((name, cur, latest, spec))

if not updates:
    print("  全部最新"); sys.exit(0)
print(f"  发现 {len(updates)} 个更新：")
for n, c, l, _ in updates: print(f"    {n}: {c} -> {l}")
if __import__('os').environ.get('NV_APPLY') == '1':
    for n, c, l, spec in updates:
        spec.write_text(re.sub(r'^VER=.*$', f'VER={l}', spec.read_text(), count=1, flags=re.M))
    print(f"  已 bump {len(updates)} 个配方")
PY

if [[ "$APPLY" == "--apply" ]]; then
    echo "[$(date -Is)] 入队构建" | tee -a "$REPORT"
    python3 - "$TREE" <<'PY' >> "$ROOT/queue.txt"
import sys, json, pathlib, re
tree = pathlib.Path(sys.argv[1])
state = json.load(open(pathlib.Path.home()/'.nvchecker'))
for spec in sorted(tree.glob('*/*/spec')):
    name = spec.parent.name
    st = state.get(name)
    if not st: continue
    latest = str(st.get('version') if isinstance(st, dict) else st).lstrip('v')
    cur = next((l[4:].strip().strip('"') for l in spec.read_text(errors='replace').splitlines() if l.startswith('VER=')), '')
    if cur and latest and cur == latest:
        print(name)
PY
    echo "  已写入 queue.txt" | tee -a "$REPORT"
    pgrep -f 'scripts/lane\.sh' >/dev/null || nohup ./scripts/lane.sh >> logs/lane-run.log 2>&1 &
fi
echo "[$(date -Is)] 完成" | tee -a "$REPORT"
