# LG110 native command-submission tracer

`lg110-iotrace.c` is a bounded, passive `LD_PRELOAD` tracer for the vendor
LoongGPU DRM interface. It associates GEM creation, VA mapping and DRM mmap
with command submissions, then logs IB metadata and a configurable number of
dwords (32 by default, capped at 512) from a tracked userspace mapping. It forwards every original ioctl/mmap unchanged.

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
`LG110_TRACE_IB_DWORDS=512` selects full IB logging for the samples below;
invalid or out-of-range values retain the 32-dword default.
Do not run an unbounded trace on a production workload.

The included `vktest-clear.log` was captured from the local `vktest-clear`
workload after vkgl 0.1.14 was installed. Four of four submissions returned
zero and all four IB dumps resolved successfully. Each submission had an IB
chunk and a FENCE chunk, a 576-byte IB on GFX ring 0, and 32 captured dwords.
The published source was also rebuilt with no warnings and run against the
published copy-texture workload: all four bounded dumps resolved; its first
four submissions were 64-byte `XDMA_COPY` IBs on `ip_type=2`, demonstrating
that the capture is workload-dependent rather than a hard-coded sample.

## Full-IB differential

With `LG110_TRACE_MAX=512` and `LG110_TRACE_IB_DWORDS=512`, both local tests
completed all 120 frames with zero unresolved or truncated dumps:

- clear: 120 GFX submissions, every 576-byte IB dumped in full (144 dwords);
- gradient: one 64-byte XDMA submission plus 120 GFX submissions, every
  1088-byte GFX IB dumped in full (272 dwords).

The first clear and gradient GFX IBs match through word 133; their shared
range differs only at words 134–143, and gradient adds words 144–271. The
complete observed header and varying-offset catalog is in
[`vktest-full-differential.md`](vktest-full-differential.md). Unknown opcodes
remain unnamed; the differential does not assign packet semantics.

A subsequent texture capture used installed vkgl 0.1.15 and completed all 120
frames: one 64-byte XDMA IB plus 120 GFX IBs, each dumped in full at 1600
bytes/400 dwords, with zero unresolved or truncated submissions. Across 119
steady-state frame pairs, texture's third observed `0x89` block aligns more
strongly with gradient's second block (114 always-equal and 16
always-different positions) than texture's second block does (97/33). See
[`vktest-texture-gradient-differential.md`](vktest-texture-gradient-differential.md).
A same-version gradient recapture on 0.1.15 also completed all 121 submissions;
its 121 IB data arrays are identical dword-for-dword to the earlier capture, so
all differential counts remain unchanged and the version-skew confound is
removed. This is still an observed alignment, not a descriptor or packet
semantic claim.

The next control, [`vktest-gradient-descriptor.c`](vktest-gradient-descriptor.c),
kept the gradient shaders and draw unchanged while adding the texture test's
combined-image-sampler layout, a valid image/view/sampler, descriptor update,
and bind. It also completed 121/121 submissions with full IB dumps, but retained
the 272-dword gradient layout and did not produce texture's third `0x89` block.
Thus descriptor creation/update/bind alone is insufficient in this no-sampling
control. The frame-matched counts and limits are cataloged in
[`vktest-gradient-descriptor-differential.md`](vktest-gradient-descriptor-differential.md).

The following [`vktest-gradient-sample.c`](vktest-gradient-sample.c) control kept
that descriptor and draw unchanged, but its
[`vktest-gradient-sample.frag`](vktest-gradient-sample.frag) executes one live
fixed-UV sample and adds a small sampled contribution to the gradient. SPIR-V
inspection confirmed one `ImageSampleImplicitLod` and an output dependency. All
121 submissions completed with full dumps; every GFX IB changed to 400 dwords
and reproduced texture's third `0x89` block. The sample/texture absolute
comparison was 386 equal and 14 different across all 400 words. Thus actual
sampling, not descriptor binding alone, was sufficient for this layout in the
tested variant. Full counts, shader evidence, and limitations are in
[`vktest-gradient-sample-differential.md`](vktest-gradient-sample-differential.md).

The [`vktest-gradient-sample-readback.c`](vktest-gradient-sample-readback.c) A/B
control then changed only the texture bytes. The installed 0.1.15 copy command was
an empty execution case, so both buffers retained their `a5a5a5a5` sentinel. The
0.1.16 implementation reads the actual render FBO; installed A/B pixels are
`00 7f 00 ff` and `00 7f 40 ff`, with only red changing by the expected 64. The
initial 512-dword trace covered 119 steady-state pairs. The independent 1024-dword
tracer subsequently captured all 120 GFX pairs completely: 672/672 for readback,
400/400 thereafter, with all 48,272 dwords equal and zero truncation. See
[`vkgl-copy-image-to-buffer-dev.md`](vkgl-copy-image-to-buffer-dev.md), the
[minimal patch](vkgl-readback-dev.patch), and the raw installed
[A](vktest-gradient-sample-readback-installed-A.rgba)/[B](vktest-gradient-sample-readback-installed-B.rgba)
pixels.

Version 0.1.17 adds padded `bufferRowLength`. The valid 2×2, rowLength=4,
bufferOffset=4 A/B buffers match all 32 expected bytes exactly; four pixels are
valid and every guard/padding byte remains `a5`. Formula, raw buffers, and patch
are in [`vkgl-buffer-row-length-readback-dev.md`](vkgl-buffer-row-length-readback-dev.md).
These establish the tested sampling/readback paths, not native Vulkan.

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
