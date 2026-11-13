#!/usr/bin/env bash
# Reproducible LG110 vkgl benchmark: 1080p FIFO, 3 rounds, records load/kernel/ICD.
set -euo pipefail

ROUNDS="${ROUNDS:-3}"
DURATION="${DURATION:-2}"
SIZE="${SIZE:-1920x1080}"
OUT="${OUT:-$PWD/vkgl-bench-$(date +%Y%m%d-%H%M%S)}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"
if [[ -z "${VK_ICD_FILENAMES:-}" && -f /usr/share/vulkan/icd.d/vkgl_loonggpu.json ]]; then
  export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/vkgl_loonggpu.json
fi

command -v vkmark >/dev/null || { echo "vkmark not found" >&2; exit 2; }
mkdir -p "$OUT"

{
  echo "date=$(date -Is)"
  echo "uname=$(uname -a)"
  echo "boot_id=$(cat /proc/sys/kernel/random/boot_id)"
  echo "load_before=$(cat /proc/loadavg)"
  echo "icd=${VK_ICD_FILENAMES:-default}"
  vulkaninfo --summary 2>/dev/null | grep -E 'deviceName|driverName|apiVersion' || true
} | tee "$OUT/conditions.log"

for i in $(seq 1 "$ROUNDS"); do
  log="$OUT/vkmark-$i.log"
  timeout 120 vkmark --winsys wayland --size "$SIZE" --present-mode fifo \
    -b "vertex:duration=$DURATION" -b "texture:duration=$DURATION" \
    -b "shading:duration=$DURATION" -b "effect2d:duration=$DURATION" \
    -b "desktop:duration=$DURATION" > "$log" 2>&1
  echo "round=$i rc=$? load=$(cat /proc/loadavg)"
  grep -E '\[vertex\]|\[texture\]|\[shading\]|\[effect2d\]|\[desktop\]|Score' "$log" || true
done | tee -a "$OUT/conditions.log"

echo "results: $OUT"
