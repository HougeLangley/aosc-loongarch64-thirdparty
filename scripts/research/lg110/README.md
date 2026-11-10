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

### Readback A/B tests

Build the published tight, padded, CopyImage, and ClearAttachments sources from
this directory.
The shader paths are relative to this directory, and the Wayland protocol
implementation is shared with the public vkgl tests:

```sh
cc -std=c11 -O2 -Wall -Wextra -Werror -I../../tests/vkgl \
  -o /tmp/vktest-readback vktest-gradient-sample-readback.c \
  ../../tests/vkgl/xdg-shell-protocol.c \
  $(pkg-config --cflags --libs wayland-client) -lvulkan
cc -std=c11 -O2 -Wall -Wextra -Werror -I../../tests/vkgl \
  -o /tmp/vktest-readback-padded vktest-gradient-sample-readback-padded.c \
  ../../tests/vkgl/xdg-shell-protocol.c \
  $(pkg-config --cflags --libs wayland-client) -lvulkan
cc -std=c11 -O2 -Wall -Wextra -Werror -I../../tests/vkgl \
  -o /tmp/vktest-copy-image vktest-gradient-copy-image.c \
  ../../tests/vkgl/xdg-shell-protocol.c \
  $(pkg-config --cflags --libs wayland-client) -lvulkan
cc -std=c11 -O2 -Wall -Wextra -Werror -I../../tests/vkgl \
  -o /tmp/vktest-clear-attachments vktest-clear-attachments.c \
  ../../tests/vkgl/xdg-shell-protocol.c \
  $(pkg-config --cflags --libs wayland-client) -lvulkan
LG110_TEXTURE_VARIANT=A LG110_READBACK_PIXEL=/tmp/readback-A.rgba \
  XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 \
  /tmp/vktest-readback
```

Use variant B and the padded/CopyImage/ClearAttachments binaries for the other
controls. The raw pixels, not just process status or a successful fence, are the
acceptance criterion. All four published sources were rebuilt with these commands
and passed their installed A/B pixel comparisons.

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

Version 0.1.18 adds a bounded same-format 2D `CopyImage` path using the source
FBO and `glCopyTexSubImage2D`. The test reads the offscreen destination, not the
source: four copied pixels and all guards/padding match exactly in A/B. The first
1024-dword tracer exposed a separate 8192-byte log-line cap (733 of 800 words);
[`lg110-iotrace-fullline.c`](lg110-iotrace-fullline.c) fixes that bound. Its A/B
runs captured all 120 GFX IBs completely, with 48,400 equal and zero different
or truncated dwords. See [`vkgl-copy-image-dev.md`](vkgl-copy-image-dev.md), the
[patch](vkgl-copy-image-dev.patch), and the raw installed
[A](vktest-gradient-copy-image-installed-A.bin)/[B](vktest-gradient-copy-image-installed-B.bin)
buffers. The optional third comparator argument selects the first GFX dword
count, for example `compare-readback-full-1024.py A.log B.log 800`.

Version 0.1.19 adds bounded in-render-pass color `ClearAttachments` using
`glScissor` and `glClear`, with FBO/scissor/clear-color/color-mask restoration.
The test deliberately disables the pipeline blue write mask, yet the clear still
writes blue=64. Separate padded buffers prove both the cleared 2x2 region and an
uncleared neighbor; all bytes and guards match in installed A/B runs. The
[`lg110-iotrace-2048.c`](lg110-iotrace-2048.c) variant captured 121 physical GFX
submissions for 120 frames, including the split first frame (800+272 dwords), for
48,672 equal and zero different/truncated dwords. Use
[`compare-clear-attachments-full.py`](compare-clear-attachments-full.py) for this
strict layout; the generic comparator intentionally rejects its 122 successful
CS. See [`vkgl-clear-attachments-dev.md`](vkgl-clear-attachments-dev.md), the
[patch](vkgl-clear-attachments-dev.patch), and the installed raw A/B clear and
neighbor buffers. Multiple attachments/rectangles are implemented but only the
1x1 combination is pixel-tested.

## Native clear-field causal control

The separate, opt-in [`lg110-native-mutation.c`](lg110-native-mutation.c)
performed the first active pre-CS experiment on 2026-11-06. With an exact
15-word signature, full writable mapping coverage, and original word 87 = 0,
it changed only that dword to `0x3f800000` before the unchanged original ioctl.
The clear-only readback changed from `66 33 00 ff` to `66 33 ff ff`; all other
IB dwords and pixel channels were identical. This establishes causal control
of clear red in this stream, not full packet semantics or native Vulkan. See
[the experiment report](lg110-native-clear-mutation.md), raw traces/pixels, and
[`build-native-mutation.sh`](build-native-mutation.sh). The earlier passive
tracer remains unchanged; do not run this mutation as an unbounded or repeated
workload.

The follow-up [`lg110-clear-color-mutation.c`](lg110-clear-color-mutation.c)
adds independent green (word88), blue (word89), and alpha (word90) controls.
RGB each produced exactly one changed IB dword and one corresponding changed
swapchain pixel byte. Swapchain alpha readback stayed 0xff even for a passive
alpha=0.5 clear, so a separate 272-dword headless optimal RGBA workload was
used: active word90 `1.0→0.5` changed only raw alpha `ff→80`. Public-source
rebuild repeated green and offscreen alpha; an offscreen red request was
rejected with zero IB changes. Full guards, raw evidence, and commands are in
[`lg110-clear-color-fields.md`](lg110-clear-color-fields.md); build with
[`build-clear-color-mutation.sh`](build-clear-color-mutation.sh). These remain
single-stream field proofs, not draw/replay or native-Vulkan support.

## Native draw-count causal control

A one-frame passive draw3/draw2 differential captured identical 16-dword XDMA
IBs and complete 672-dword GFX IBs. Only word270 (`3→2`) and word276 (`2→1`)
changed; the center changed from gradient `007f00ff` to clear `663300ff`.
The opt-in [`lg110-draw-count-mutation.c`](lg110-draw-count-mutation.c) then
changed **only word270** in a draw3 stream, leaving word276=2. The draw was
suppressed and raw became byte-identical to passive draw2. This establishes
vertex-count causality for word270 in this stream; word276 remains unnamed.
An already-draw2 input is rejected with zero IB changes. Public strict rebuild
repeated all four passive/active/guard cases. See
[`lg110-draw-count-field.md`](lg110-draw-count-field.md) and
[`build-draw-count-mutation.sh`](build-draw-count-mutation.sh).

## Native draw-topology causal control

Installed 0.1.20 first gave a negative control: point and triangle requests had
identical IBs/pixels because vkgl hardcoded `GL_TRIANGLES`. The 0.1.21 fix maps
all six basic topologies. Passive full-IB differentials then isolated word268
to values `0x40000000`, `…0100`, `…0300`, `…0400`, `…0500`, `…0600` for
point/line/line-strip/triangle/strip/fan respectively. Active triangle→point
changed only word268 and exactly reproduced passive point raw; count regression
and already-point rejection passed. Word273 does not track topology and remains
unassigned. Adjacency/PATCH are rejected rather than misdrawn. See
[`lg110-draw-topology-field.md`](lg110-draw-topology-field.md), the extended
tracer/test, and `draw-topology-*` raw evidence.

## Native firstVertex causal control

A safe four-vertex shader avoids out-of-bounds vertex indices. Passive first0→1
changes words274/275/276, but active separation shows that word274 alone exactly
reproduces the passive first1 pixel, while word275 or word276 alone does not.
The already-first1 guard and all count/topology/word276 regressions pass. This is
a limited first-vertex causal proof, not vertex addressing or replay. See
[`lg110-first-vertex-field.md`](lg110-first-vertex-field.md) and
`draw-first-public-*` evidence.

## Indexed and indirect native differential

With installed vkgl 0.1.27, Vulkan indirect recording expands to the same GL draw:
direct→indirect changes only 12 GPU-VA-bearing positions. Indexed adds a six-byte
XDMA upload and changes four additional GFX fields: word268 gains `0x2`, word276
becomes `0xffffffff`, word280 equals the traced index GEM VA, and word281 is 1 on
this UINT16 path. The UINT32 follow-up leaves word281 unchanged and isolates
word268 `0x40000402↔0x40000404`; a guarded active reverse mutation exactly
reproduces the old UINT32-as-UINT16 clear pixel. This proves index-width
causality for word268, while word281 remains unassigned. See
[`lg110-indexed-draw-field.md`](lg110-indexed-draw-field.md),
[`lg110-index-type-field.md`](lg110-index-type-field.md), and the
`draw-indexed-public-*` / `draw-index-type-public-*` complete traces.

## Native firstIndex and signed base vertex

The 0.1.29 four-vertex indexed test separates firstIndex from vertexOffset.
Passive streams isolate word269 `0→3` for firstIndex and word274 for base vertex;
word274 is 1 for +1 and `0xffffffff` for -1. Guarded active mutations of word269
alone, word274 0→1, and word274 -1→0 each produce the exact corresponding clear
pixel with no XDMA change and only the target GFX dword changed. Two wrong-input
guards reject with zero changes. See
[`lg110-index-offset-field.md`](lg110-index-offset-field.md) and
`draw-index-offset-public-*` traces. This is not arbitrary packet/replay proof.

## Independent vertex bindings

The 0.1.30 test supplies positions and UVs from different VBOs, offsets and
strides. Four direct/indexed/indirect captures pass and show separate XDMA
uploads, but neither VBO base VA occurs literally in the 672-dword GFX stream;
only the index VA still maps to word280. No vertex-address field is guessed and
no active VBO mutation is attempted. See
[`lg110-vertex-binding-stream.md`](lg110-vertex-binding-stream.md) and
`draw-vertex-binding-public-*` traces.

## Vertex-state auxiliary BOs and CPU profile

Constant-pixel offset/stride controls leave both XDMA IBs and the 672-dword GFX
IB unchanged. A new opt-in tracer can temporarily map one explicitly selected,
tracked BO read-only; the first 64 dwords of two GFX-referenced auxiliary BOs are
also unchanged. This is a bounded negative result, not a vertex decoder. Default
and invalid-VA guards are tested. See
[`lg110-vertex-state-bo.md`](lg110-vertex-state-bo.md).

The follow-up A/B/A test removes cross-process noise and second-pipeline lazy
initialization. After initialization, stride 16 -> 8 differs from the same
control only by GFX words 338/362 selecting different state BOs; the selected
16K BO pairs are content-identical, so these are not numeric stride fields.
Offset adds no small-BO difference. Same-state cross-process hashes are retained
as a negative control. See [`lg110-vertex-state-aba.md`](lg110-vertex-state-aba.md).

Long cpu-clock profiles show vkgl at only 5.4–5.6% of sampled CPU, versus 23–28%
in `gsgpu_dri.so`; unknown samples are not misassigned. No new CPU micro-
optimization was released on these small samples. See
[`lg110-cpu-profile-0.1.31.md`](lg110-cpu-profile-0.1.31.md) for textual flat,
DSO and call-graph evidence (binary perf.data excluded).

## Sampler capability is not sufficient proof

LG110 exposes `GL_EXT_texture_filter_anisotropic` and maximum 16 on the hardware
Wayland GLES2 context. An isolated vkgl prototype successfully set/read back 16x,
but a controlled magnification sample changed from the correct LINEAR raw
`007f22ff` to the NEAREST value `007f40ff`. The feature therefore remains off in
0.1.23. See [`lg110-sampler-anisotropy.md`](lg110-sampler-anisotropy.md) for the
state/pixel evidence and the future magnification-plus-minification gate.

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

## word273 remains unassigned after active separation

On installed 0.1.32, a newly guarded `word273` mode changes only that dword from
3 to 2 in the original nonindexed 672-dword stream. The XDMA is unchanged, the
complete GFX differential contains only word273, and the center remains the base
`007f00ff`. Input draw2 is rejected with zero mutations; the existing word270
count regression still changes only word270 and produces `663300ff`. Therefore
word273 alone is not sufficient for the count effect and is not named a second
count field. This is a bounded negative causal result, not proof that it is
unused. See [`lg110-draw-word273-field.md`](lg110-draw-word273-field.md).

## Indexed word281 also remains unassigned

The 0.1.32 indexed UINT16 stream keeps a valid nonzero index VA while a guarded
mode changes only word281 `1→0`. Both 16-dword XDMA IBs are unchanged, the full
672-dword GFX diff contains only word281, and the center remains `663300ff`.
Nonindexed input is rejected with zero mutations. A paired UINT32 control and
the existing index32-to16 regression still differ only at word268 and change
`007f00ff→663300ff`. Word281 alone is therefore insufficient for this output;
it is not called unused, firstInstance, or index width. See
[`lg110-draw-word281-field.md`](lg110-draw-word281-field.md).

## Primitive restart: broken GL enables, software fix

Restart-off/on indexed strip captures on installed 0.1.32 have identical XDMA and
all 672 GFX dwords, confirming that vkgl drops `primitiveRestartEnable`. Although
the vendor advertises `GL_NV_primitive_restart` and its index setter,
`glEnable(GL_PRIMITIVE_RESTART_NV)` returns `GL_INVALID_ENUM` and the state stays
disabled. An isolated forwarding candidate reproduced that error inside vkgl and
changed no IB dword, so it was rejected and not installed. Core and fixed-index
restart enables also return `GL_INVALID_ENUM` with enabled=0. Word276 remains
unassigned. 0.1.33 instead splits the existing CPU index shadow at real
UINT16/UINT32 sentinels; strip/fan and direct/indirect pixel tests pass, while
no-sentinel native IBs remain identical. See
[`lg110-primitive-restart.md`](lg110-primitive-restart.md) and the
[0.1.33 release report](../../tests/vkgl/vkgl-0.1.33.md).

A segment-cache candidate eliminated 119 of 120 static scans and correctly
rescanned mapped UINT16/32 updates, but both Buffer-local and external-map
revisions had negative paired default-path results. It is reproducible as a
patch but was not installed or released. See
[`vkgl-primitive-restart-cache.md`](vkgl-primitive-restart-cache.md); the scan
reduction is not an FPS claim.

## Fragment uniform lives outside the captured IB

A same-driver red/blue UpdateBuffer workload produced exact distinct pixels but
zero differences in the complete 16-dword XDMA, 544-dword GFX draw, and
272-dword readback IBs. Bounded mapped-BO hashes then isolated a 16 MiB handle-8
state mapping. Its red/blue snapshots differed only inside the vec4 at offset
`0x3cb0`. A separate opt-in, old-value-guarded mutation of that vector from red
to green before submission 2 produced exact green/black output, while the
passive control stayed red. This is causal evidence for one tested fragment
uniform field, not a portable descriptor/UAPI or performance result. See
[`lg110-uniform-state.md`](lg110-uniform-state.md).

A follow-up resolved GFX words 240/241 as the exact little-endian VA of that
vec4. Writing green into an unused following BO slot while leaving the IB
unchanged still rendered red; additionally changing only word240 to the new VA
rendered green, with no other differences across all 832 IB dwords. This is a
causal pointer result for this stream, not a generic packet format. See
[`lg110-uniform-pointer.md`](lg110-uniform-pointer.md).

A content-keyed uniform-upload cache passed exact UpdateBuffer/vertex/fragment
regressions but recorded **zero hits** in vertex (360 uploads), texture (240),
and shading (240). It skipped no GL calls and was rejected without a paired FPS
claim or installation. See [`vkgl-uniform-cache.md`](vkgl-uniform-cache.md).

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
