# LG110 native command-submission tracer

`lg110-iotrace.c` is a bounded, passive `LD_PRELOAD` tracer for the vendor
LoongGPU DRM interface. It associates GEM creation, VA mapping and DRM mmap
with command submissions, then logs IB metadata and at most 32 dwords from a
tracked userspace mapping. It forwards every original ioctl/mmap unchanged.

This is a reverse-engineering tool, not a Vulkan driver. It does not submit
packets, program registers, or change the desktop/driver configuration.

## Build

The LoongGPU 1.0.2 DKMS headers and libdrm headers are required:

```sh
cc -std=c11 -O2 -g -fPIC -shared -Wall -Wextra -Wpedantic \
  $(pkg-config --cflags libdrm) \
  -I/usr/src/loonggpu-1.0.2/include \
  -o lg110-iotrace.so lg110-iotrace.c -ldl -lpthread
```

## Capture

Run a known small Wayland/vkgl workload in an active hardware-rendered desktop.
For a fully published workload, build `vktest-copy-texture` as documented in
`scripts/tests/vkgl/README.md`, then run from that test directory so its SPIR-V
files resolve:

```sh
timeout 3s env -u VK_ICD_FILENAMES \
  LD_PRELOAD="$PWD/../../research/lg110/lg110-iotrace.so" \
  LG110_TRACE_MAX=4 LG110_TRACE_AUX_MAX=0 \
  XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
  ./vktest-copy-texture > /tmp/lg110-copy.log 2>&1
```

Exit 124 is expected from `timeout`. `LG110_TRACE_MAX` defaults to 64 and is
capped; `LG110_TRACE_AUX_MAX` separately enables bounded VA diagnostics.
Do not run an unbounded trace on a production workload.

The included `vktest-clear.log` was captured from the local `vktest-clear`
workload after vkgl 0.1.14 was installed. Four of four submissions returned
zero and all four IB dumps resolved successfully. Each submission had an IB
chunk and a FENCE chunk, a 576-byte IB on GFX ring 0, and 32 captured dwords.
The published source was also rebuilt with no warnings and run against the
published copy-texture workload: all four bounded dumps resolved; its first
four submissions were 64-byte `XDMA_COPY` IBs on `ip_type=2`, demonstrating
that the capture is workload-dependent rather than a hard-coded sample.

## Verified ABI detail

The installed vendor userspace issues GEM_VA as request `0xc0286448` (IOWR),
whereas the supplied public 1.0.2 header computes `0x40286448` (IOW). The
payload and command number are identical. The tracer accepts both encodings
but always forwards the application's original request unchanged.

The sample starts with:

```text
0x00010088 0x00000003 0x00810089 0x0000000f
0x41010f00 0x00000000 0x00000003 0x00000000
```

The supplied GSPKT list does not name opcode `0x88`, so it remains UNKNOWN.
The kernel header only comments `DRAW 0x89`; these observations are not yet a
packet disassembler or proof of payload semantics.

## Limitations

- Same-process intercepted calls only; direct syscalls and unobserved imports,
  userptr, fork/dup/close or mremap can leave incomplete associations.
- Fixed capacities: 256 GEM records, 512 VA records, 256 mappings and 32 logged
  chunks per submission.
- IB data is a post-ioctl userspace snapshot, not an atomic GPU execution
  capture. A bounded direct-read fallback is used only after a tracked mapping
  covers the range; concurrent unmapping remains a small race.
- This sample had no syncobj chunks, although syncobj metadata handling exists.
- Successful tracing does not implement native Vulkan or establish native
  rendering correctness.
