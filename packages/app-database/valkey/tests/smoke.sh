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

# 使用包内配置和包内状态目录启动真实服务；仅把网络监听换成私有 Unix socket。
[[ -d ./var/lib/valkey && -w ./var/lib/valkey ]] || {
  echo 'valkey package state directory is missing or not writable' >&2
  exit 1
}
T="$(mktemp -d /tmp/valkey-package-smoke.XXXXXX)"
sed "s|^dir /var/lib/valkey/$|dir $PWD/var/lib/valkey|" \
  ./etc/valkey/valkey.conf > "$T/valkey.conf"
cleanup() {
  ./usr/bin/valkey-cli -s "$T/socket" shutdown nosave >/dev/null 2>&1 || true
  if [[ -s "$T/valkey.pid" ]]; then kill -TERM "$(cat "$T/valkey.pid")" 2>/dev/null || true; fi
  rm -rf -- "$T"
}
trap cleanup EXIT
./usr/bin/valkey-server "$T/valkey.conf" \
  --port 0 --unixsocket "$T/socket" \
  --pidfile "$T/valkey.pid" --daemonize yes --logfile "$T/valkey.log"
ready=0
for _ in $(seq 1 100); do
  if [[ "$(./usr/bin/valkey-cli -s "$T/socket" ping 2>/dev/null)" == PONG ]]; then ready=1; break; fi
  sleep 0.1
done
[[ $ready -eq 1 ]] || { cat "$T/valkey.log" >&2; exit 1; }
[[ "$(./usr/bin/valkey-cli -s "$T/socket" set package-smoke expected-value)" == OK ]]
[[ "$(./usr/bin/valkey-cli -s "$T/socket" get package-smoke)" == expected-value ]]
printf 'valkey packaged config/state directory server smoke: PASS\n'
