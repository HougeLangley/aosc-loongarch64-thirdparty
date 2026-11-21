#!/usr/bin/env bash
# 在 smoke-test.sh 解包后的根目录运行：主程序与 core 必须来自同一 v2rayA 版本。
set -euo pipefail
main_output="$(./usr/bin/v2raya --version)"
core_output="$(./usr/bin/v2raya_core --version)"
main_version="$(awk 'NR == 1 { print $1 }' <<<"$main_output")"
core_version="$(awk 'NR == 1 && $1 == "V2RAYA_CORE" { print $2 }' <<<"$core_output")"
[[ -n "$main_version" && "$main_version" == "$core_version" ]] || {
  echo "v2raya/core mismatch: main=${main_version:-unknown}, core=${core_version:-unknown}" >&2
  exit 1
}
printf 'v2raya and v2raya_core versions match: %s\n' "$main_version"
