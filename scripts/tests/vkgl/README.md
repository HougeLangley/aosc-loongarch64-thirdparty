# vkgl Wayland / linear-image regression tests

These tests require an active Wayland desktop and the vkgl ICD. They do not
accept llvmpipe as a valid result.

## Build

```sh
cc -std=gnu11 -O2 -o vktest-acquire vktest-acquire.c xdg-shell-protocol.c \
  $(pkg-config --cflags --libs wayland-client) -lvulkan
cc -std=gnu11 -O2 -o vktest-copy-texture vktest-copy-texture.c \
  xdg-shell-protocol.c $(pkg-config --cflags --libs wayland-client) -lvulkan
```

Run each test normally for dma-buf presentation and with
`VKGL_NO_DMABUF=1` for the wl_shm path.

## Acquire exclusivity and fence

`vktest-acquire` acquires every swapchain image without presenting, checks that
no image is returned twice and that each successful acquire signals its fence.
The next timeout=0 acquire must return `VK_TIMEOUT` or `VK_NOT_READY`. It then
presents the images and verifies that a compositor release makes an image
acquirable again.

Expected output:

```text
PASS vktest-acquire (2 exclusive images, fence signaled, release reacquired)
```

## CopyBufferToImage into a linear image

`vktest-copy-texture` copies a 64x64 RGBA image from a staging buffer whose
`bufferRowLength` is 128. The destination image has never been mapped, so its
initial shadow is zero. The copied texture must render as a 640x480 rectangle
with a red top half and blue bottom half.

A process exit of zero alone does not verify the pixels. While the test is
running, capture the screen and check the image:

```sh
spectacle -b -n -o /tmp/vkgl-copy.png
python3 check-copy-texture.py /tmp/vkgl-copy.png
```

Expected result for both presentation paths:

```text
PASS: red=153600 blue=153600
```

The vkgl 0.1.13 control produces `red=0 blue=0`; the fixed version preserves
both copied pixels and padded-row layout.

The test presents 30 frames with 100 ms sleeps. Start it in the background and
capture after about one second, then wait for it; capturing after three seconds
can photograph the closed window and is not a driver failure.

## vkmark 2025.01-4: validation cleanup

`vktest-wsi-semaphore.c` isolates legal acquire-semaphore reuse with submit
fences; both present paths have zero acquire/signal VUIDs. The corrected vkmark
package separately adds per-image render-finished semaphores, valid OPTIMAL
initial layouts and capability-clamped anisotropy. Its five-scene smoke dropped
from 28 to **0 validation events** on both dmabuf and wl_shm without changing
vkgl 0.1.26. See [vkmark-2025.01-4-wsi-validation.md](vkmark-2025.01-4-wsi-validation.md).

## 0.1.28 UINT16/UINT32 index types

Build the updated matrix with `./build-0.1.28-tests.sh /tmp/vkgl-0.1.28-tests`.
The 16 indexed direct/indirect cases cover both index widths and the four
instance controls. Exact 0.1.27 fails both UINT32 pixel cases; installed 0.1.28
passes all 16 with zero validation events. The native differential and guarded
active mutation also identify word268's 16/32-bit encoding effect. See
[vkgl-0.1.28.md](vkgl-0.1.28.md) and
[../../research/lg110/lg110-index-type-field.md](../../research/lg110/lg110-index-type-field.md).

## 0.1.27 software instancing

Build the strict direct/indexed/indirect instance matrix and all earlier tests:

```sh
./build-0.1.27-tests.sh /tmp/vkgl-0.1.27-tests
```

Run `vktest-draw-instance` from `/tmp/vkgl-0.1.27-tests/instance`. The 16-case
matrix covers instanceCount=0/1/2 and firstInstance=0/1 across direct, indexed,
indirect and indexed-indirect recording. Installed 0.1.27 passes every raw-pixel
case with zero validation events. The vendor GL context has no instancing
extension, so vkgl uses an internal instance uniform and repeated GL draws; this
is not native Vulkan or hardware instancing. Noninstanced paired benchmarks show
only noise-level differences. See [vkgl-0.1.27.md](vkgl-0.1.27.md).

## 0.1.26 coherent upload coalescing

Build the controlled persistent-mapping test and all earlier strict tests:

```sh
./build-0.1.26-tests.sh /tmp/vkgl-0.1.26-tests
```

`../../research/lg110/vktest-coherent-upload.c` changes a persistently mapped
coherent texture between submissions and validates second-frame pixels without
Flush/Unmap. Exact 0.1.25 and 0.1.26 return `007f40ff`; the deliberately broken
revision-only control returns stale `007f00ff` and fails.

`../../research/lg110/coherent-upload-ab.py` runs the alternating N-draw scaling
benchmark. With 64 draws per 256x256-texture submission, median FPS increased
from 21.683 to 114.972 (+430.24%, 5/5); the one-draw control changed only +1.57%.
This is an upload-heavy controlled result, not a universal Vulkan speedup.
Ordinary vkmark data remains published and is not claimed to improve.

See [vkgl-0.1.26.md](vkgl-0.1.26.md) for commands, raw evidence and release hashes.

## 0.1.25 dispatchable lifetime

Build and run the 64-cycle lifecycle regression:

```sh
./build-0.1.25-tests.sh /tmp/vkgl-0.1.25-tests
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/vkgl_loonggpu.json \
VK_DRIVER_FILES="$VK_ICD_FILENAMES" \
  /tmp/vkgl-0.1.25-tests/vktest-dispatch-lifetime
```

Vulkan loaders replace the first word of dispatchable objects with a dispatch
table. 0.1.25 avoids dispatching C++ virtual destructors through that word for
Instance, Device, Queue and CommandBuffer. The minimal test also passes on older
releases and is not a standalone negative control; the rendered crash, gdb first
word and ASan differential are documented in
[vkgl-0.1.25.md](vkgl-0.1.25.md).

This is a correctness release, not a performance improvement. Rejected debug-
cache/alignment/cold combinations and the final unfavorable paired FPS data are
all retained in the report.

## 0.1.24 compiler comparison

0.1.24 keeps the 0.1.23 source and changes only the build flags to
`-O3 -march=loongarch64 -mtune=la664 -flto`. The ISA remains the LoongArch64
baseline; LA664 is tuning only. The package library is byte-identical to the
measured candidate.

Five paired rounds under recorded Homebrew build load gave LTO median gains of
7.07% vertex, 5.83% texture and 2.00% shading. O3 without LTO was rejected
because vertex fell 6.15% despite a larger shading gain. Both favorable and
unfavorable JSONL results, load records, exact pixels and smoke logs are in
[vkgl-0.1.24.md](vkgl-0.1.24.md). This is a limited small-scene result, not a
universal or maximum-performance claim.

## 0.1.23 real sampler state

Build without running a GPU:

```sh
./build-0.1.23-tests.sh /tmp/vkgl-0.1.23-tests
/tmp/vkgl-0.1.23-tests/vktest-sampler-create
```

For the split-texture pixel oracle, run from `scripts/research/lg110` with the
installed ICD and active Wayland session:

```sh
LG110_TEXTURE_VARIANT=B LG110_SAMPLER_PATTERN=split \
LG110_FRAGMENT_SHADER=/tmp/vkgl-0.1.23-tests/vktest-sampler-offset.frag.spv \
LG110_FRAME_LIMIT=1 LG110_SAMPLER_FILTER=linear LG110_SAMPLER_WRAP=clamp \
LG110_READBACK_PIXEL=/tmp/sampler-linear.rgba \
  /tmp/vkgl-0.1.23-tests/vktest-gradient-sample-readback
```

Use `LG110_SAMPLER_FILTER=nearest` for the other oracle. LINEAR must produce raw
`007f22ff`; NEAREST produces `007f40ff`. The same linear test fails on 0.1.22.
Wrap can be `clamp`, `repeat` or `mirrored`; `VKGL_DEBUG=1` adds actual GL state
readback. Three draws with unchanged state must log only one `sampler applied`.

Anisotropy remains feature=0/max=1 because the 16x prototype failed its pixel
gate. Validation stays at 28 events/four classes. See
[vkgl-0.1.23.md](vkgl-0.1.23.md) and
[the anisotropy negative result](../../research/lg110/lg110-sampler-anisotropy.md).
Raw high-load performance data is published without an improvement claim.

## 0.1.22 format capabilities and validation reduction

Build the strict format test plus existing upload/fence tests without running a
GPU:

```sh
./build-0.1.22-tests.sh /tmp/vkgl-0.1.22-tests
VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/vkgl_loonggpu.json \
VK_DRIVER_FILES="$VK_ICD_FILENAMES" \
  /tmp/vkgl-0.1.22-tests/vktest-format-properties
```

The same binary fails on 0.1.21 and passes on 0.1.22. Four RGBA8 formats now
report actual linear-filter/color-blend support, four SFLOAT vertex formats
report vertex-buffer support, and core FormatProperties2 agrees. Both public
smoke paths fall from 59 events/eight VUID classes to 28/four; exactly 31
format-related events disappear with no new diagnostics. Validation remains not
clean: application image-layout/anisotropy inputs and binary-semaphore reuse are
documented separately. Full pixels, topology, fences, acquire and package hashes
are in [vkgl-0.1.22.md](vkgl-0.1.22.md). No performance claim is made.

## 0.1.21 topology and honest smoke diagnostics

`run-vkgl-smoke.sh ICD_JSON LABEL [OUTPUT_DIR]` runs vulkaninfo, 60 vkcube
frames, and five two-second FIFO vkmark scenes on dmabuf and wl_shm. It rejects
software rendering/crashes and prints `validation_errors=N`; it does not silently
treat a failing `! grep` as a clean validation gate. Use
`REQUIRE_VALIDATION_CLEAN=1` to make diagnostics fatal.

The exact 0.1.20 baseline and installed 0.1.21 each produce 59 events in eight
VUID classes per path with identical per-class counters. Rendering is GPU-only,
but validation is not clean and remains follow-up work. Six basic topology pixel
checks, native word268 causality, unsupported-topology rejection, and release
hashes are documented in [vkgl-0.1.21.md](vkgl-0.1.21.md) and
[the native topology report](../../research/lg110/lg110-draw-topology-field.md).
No performance improvement is claimed.

## 0.1.20 tight-upload and real submission-fence tests

Build without initializing a GPU:

```sh
./build-0.1.20-tests.sh /tmp/vkgl-0.1.20-tests
/tmp/vkgl-0.1.20-tests/vktest-submit-fence
/tmp/vkgl-0.1.20-tests/vktest-tight-upload --check
```

`vktest-tight-upload` checks optimal/linear padded references against tight
`bufferRowLength=0` and `=width`, with nonzero buffer/image offsets and exact
border pixels. `--bench 64 1024 1024 7` measures seven batches of 64 1024²
RGBA uploads. `vktest-submit-fence` runs 11 deterministic host-only cases;
`vktest-submit-fence-gpu` additionally checks real vendor EGL submission,
reset/reuse, waitAll/waitAny, zero-timeout behavior, and exact readback in the
active Wayland session.

The installed 0.1.19-to-0.1.20 paired result is **+6.67% tight-upload
throughput, 5/5 pairs**, with a **-0.53% padded control**. This is not an FPS
or native-Vulkan claim. See [the full release report](vkgl-0.1.20.md) and the
raw `tight-upload-installed-ab-0.1.20.{log,json}` files.

## Paired clear fast-path benchmark

`clear-ab.py` alternates two ICD manifests over vertex, texture and shading,
writing machine-readable JSON Lines. Example:

```sh
python3 clear-ab.py --base /path/to/0.1.14.json \
  --candidate /path/to/0.1.15.json --rounds 6 --duration 5 \
  --output clear-ab-0.1.15.jsonl
```

The checked-in `clear-ab-0.1.15.jsonl` records the final integrated 0.1.15
build against the installed 0.1.14 control. Small single-run differences are
not valid performance claims; use the paired rounds and report medians.

Repeat at 1080p with `--size 1920x1080 --rounds 4`. The checked-in
`clear-ab-0.1.15-1080p.jsonl` has 24 successful runs and all 12 pairs improved:

| Scene | 0.1.14 median FPS | 0.1.15 median FPS | Change |
| --- | ---: | ---: | ---: |
| vertex | 21.5 | 27.5 | +27.9% |
| texture | 20.5 | 26.0 | +26.8% |
| shading | 21.0 | 25.0 | +19.0% |

Both variants mapped the vendor gsgpu EGL stack, had three zero-copy dmabuf
swapchain images, and had no llvmpipe mapping. `clear-ab-0.1.15-1080p-metadata.json`
records unchanged binary hashes throughout the matrix. These results apply
only to the measured scenes and settings.
