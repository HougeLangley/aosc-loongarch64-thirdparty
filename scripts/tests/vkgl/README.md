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
[the native topology report](../research/lg110/lg110-draw-topology-field.md).
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
