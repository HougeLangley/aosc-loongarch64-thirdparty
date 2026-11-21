#!/usr/bin/env bash
# 在 smoke-test 解包根中执行；覆盖 usr/share 下自动探测不到的真实脚本。
set -euo pipefail
SCRIPT=./usr/share/mk/meta2deps.py
[[ -x "$SCRIPT" ]]
[[ "$(head -n 1 "$SCRIPT")" == '#!/usr/bin/python3' ]]
# AOSC 不提供未版本化的 python；env -i 防止宿主 shell 环境掩盖解释器问题。
env -i PATH=/usr/bin:/bin "$SCRIPT" </dev/null
version="$(MAKESYSPATH="$PWD/usr/share/mk" ./usr/bin/bmake -V MAKE_VERSION)"
[[ "$version" =~ ^[0-9]{8}$ ]]
printf 'bmake smoke: MAKE_VERSION=%s; meta2deps direct execution PASS\n' "$version"
