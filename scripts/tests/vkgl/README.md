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
