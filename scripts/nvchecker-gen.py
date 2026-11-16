#!/usr/bin/env python3
"""从第三方配方生成 nvchecker.toml（任务①：定时检查上游更新）。

判定规则（按 SRCS 里的 URL 形状）：
  github.com/<o>/<r>          -> source = "github"
  gitlab.com/<o>/<r>          -> source = "gitlab"
  pypi / pythonhosted          -> source = "pypi"
  crates.io                    -> source = "cratesio"
  其它 git::                    -> source = "git"（用 tag_pattern）
"""
import re, sys, pathlib

TREE = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else
                    "/home/houge/build/tree/aosc-loongarch64-thirdparty/packages")

def parse_spec(p):
    d = {}
    for line in p.read_text(errors="replace").splitlines():
        m = re.match(r'^(VER|REL|SRCS|CHKUPDATE)=(.*)$', line.strip())
        if m:
            d[m.group(1)] = m.group(2).strip().strip('"')
    return d

def classify(srcs):
    if 'github.com' in srcs:
        m = re.search(r'github\.com/([\w.-]+)/([\w.-]+)', srcs)
        if m: return 'github', m.group(1), m.group(2)
    if 'gitlab.com' in srcs:
        m = re.search(r'gitlab\.com/([\w./-]+?)(?:\.git|::|"|$)', srcs)
        if m: return 'gitlab', m.group(1), ''
    if 'pypi.org' in srcs or 'pythonhosted' in srcs:
        return 'pypi', '', ''
    if 'crates.io' in srcs:
        return 'cratesio', '', ''
    m = re.search(r'git::[^:]*::(https?://\S+?)(?:"|$)', srcs)
    if m: return 'git', m.group(1), ''
    return None, '', ''

entries, skipped = [], []
for spec in sorted(TREE.glob('*/*/spec')):
    name = spec.parent.name
    d = parse_spec(spec)
    ver, srcs = d.get('VER', ''), d.get('SRCS', '')
    if not ver or not srcs:
        skipped.append((name, '无 VER/SRCS')); continue
    kind, a, b = classify(srcs)
    if not kind:
        skipped.append((name, '无法识别源类型')); continue
    entries.append((name, kind, a, b, ver, srcs))

out = [f"# 自动生成：{len(entries)} 个第三方包", "# 由 scripts/nvchecker-gen.py 产出，勿手改", ""]
for name, kind, a, b, ver, srcs in entries:
    out.append(f'["{name}"]')
    if kind == 'github':
        # 用 git 源 + use_max_tag 取 tag；github 源默认返回 commit 日期，与配方 VER 不可比
        out.append('source = "git"')
        out.append(f'git = "https://github.com/{a}/{b}"')
        out.append('use_max_tag = true')
    elif kind == 'gitlab':
        out.append('source = "git"')
        out.append(f'git = "https://gitlab.com/{a}"')
        out.append('use_max_tag = true')
    elif kind == 'pypi':
        out.append(f'source = "pypi"'); out.append(f'pypi = "{name}"')
    elif kind == 'cratesio':
        out.append(f'source = "cratesio"'); out.append(f'cratesio = "{name}"')
    else:
        out.append(f'source = "git"'); out.append(f'git = "{a}"')
        out.append('use_max_tag = true'); out.append('tag_pattern = "[0-9].*"')
    # 前缀/子路径从 SRCS 的 tags/ 段推断（教训 L407：混合 tag 格式会选错版本）
    m = re.search(r'tags/(.+?)(?:\$VER|\$\{VER\}|[0-9][^:"]*)::', srcs + '::')
    tagpart = m.group(1) if m else ''
    if tagpart.endswith('/'):
        # 形如 tags/kustomize/v$VER -> 子路径 kustomize/ + 前缀 v
        out.append(f'prefix = "{tagpart}"   # 当前 {ver}')
    elif tagpart in ('v', ''):
        out.append(f'prefix = "{tagpart}"   # 当前 {ver}')
    elif tagpart.endswith('v'):
        out.append(f'prefix = "{tagpart}"   # 当前 {ver}')
    else:
        # 硬编码版本或无前缀
        out.append(f'# 前缀推断为 {tagpart!r}（SRCS 可能硬编码版本）  当前 {ver}')
    out.append("")

print("\n".join(out))
print(f"# --- 统计 ---", file=sys.stderr)
print(f"# 生成 {len(entries)} 条，跳过 {len(skipped)} 条", file=sys.stderr)
for n, r in skipped: print(f"#   跳过 {n}: {r}", file=sys.stderr)
