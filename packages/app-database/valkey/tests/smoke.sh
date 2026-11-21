#!/usr/bin/env bash
# valkey 的服务端与基准工具必须来自同一个上游版本。
set -euo pipefail
server_output="$(./usr/bin/valkey-server --version)"
benchmark_output="$(./usr/bin/valkey-benchmark --version)"
server_version="$(sed -n 's/^Valkey server v=\([^ ]*\).*/\1/p' <<<"$server_output")"
benchmark_version="$(awk '$1 == "valkey-benchmark" { print $2 }' <<<"$benchmark_output")"
[[ -n "$server_version" && "$server_version" == "$benchmark_version" ]] || {
  echo "valkey server/benchmark mismatch: server=${server_version:-unknown}, benchmark=${benchmark_version:-unknown}" >&2
  exit 1
}
printf 'valkey server and benchmark versions match: %s\n' "$server_version"
