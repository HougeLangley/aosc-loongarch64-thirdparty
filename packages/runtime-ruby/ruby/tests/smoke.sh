#!/usr/bin/env bash
# Real ruby runtime and the libcrypt linkage found by the ELF dependency audit.
set -euo pipefail
[[ "$(ruby -e 'print RUBY_VERSION')" == 4.0.9 ]]
readelf -d /usr/bin/ruby | grep -F 'libcrypt.so.2' >/dev/null
dpkg-query -W -f='${db:Status-Status}\n' libxcrypt | grep -Fx installed >/dev/null
actual="$(ruby -rjson -e 'puts JSON.generate({a:[1,2,3],b:"ok"})')"
[[ "$actual" == '{"a":[1,2,3],"b":"ok"}' ]]
echo "ruby $actual libcrypt linkage/dependency: PASS"
