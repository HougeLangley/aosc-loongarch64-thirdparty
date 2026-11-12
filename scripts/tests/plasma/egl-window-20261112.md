# Plasmashell WINDOW/PBUFFER EGL diagnosis and 1.0.4 validation

Date: 2026-11-12

## Result

The current gsgpu driver exposes 12 EGL configurations, all with
`EGL_SURFACE_TYPE=EGL_WINDOW_BIT`; it exposes no PBUFFER configurations. The
historical `gsgpu-egl-window-compat.so` changed Qt's usable WINDOW request to
PBUFFER and caused the null EGLConfig and subsequent null-surface warnings.
`plasma-loonggpu-compat 1.0.4-1` removes that shim from the package and clears
Plasmashell's `LD_PRELOAD`. KWin's fd-reuse and dmabuf bridge are unchanged.

This diagnosis used short-lived, independent test processes in the existing
Wayland session. It did not attach to Plasmashell or infer a live native
backtrace. No software renderer was used.

## Independent reproduction

Build the preserved sources:

```bash
g++ -std=c++17 -fPIC qwl-minimal.cpp -o qwl-minimal \
  $(pkg-config --cflags --libs Qt6Gui) -lEGL
gcc egl-config-matrix.c -o egl-config-matrix -lEGL -lwayland-client
```

Run with the normal Wayland session and gsgpu EGL vendor environment. The
negative control must use the retained 1.0.3 library and `--plasma-name` to pass
its process-name gate:

```bash
env -u LD_PRELOAD ./qwl-minimal
LD_PRELOAD=/usr/lib/loonggpu/gsgpu-egl-window-compat.so \
  ./qwl-minimal --plasma-name
./egl-config-matrix
```

| Test | Positive control, no shim | Historical production shim |
|---|---|---|
| Qt default complete WINDOW request | 6 configs | rewritten to PBUFFER: 0 configs |
| Native window draw surface | non-null | null |
| `makeCurrent`, `eglSwapInterval(0)`, swap | pass | `EGL_BAD_CONFIG` / `EGL_BAD_SURFACE` |
| Strict test exit | 0 | 22 (surfaceless false success rejected) |
| GL renderer | LoongGPU LG110 | LoongGPU LG110 |

The complete matrix reports:

```text
WINDOW_only=12
PBUFFER_only=0
WINDOW+OPENGL=12
PBUFFER+OPENGL=0
complete Qt WINDOW request=6
complete Qt PBUFFER request=0
WINDOW|PBUFFER+OPENGL=0
```

All 12 configurations have `RENDERABLE_TYPE=ES1|ES2|OPENGL`. Therefore the
failing attribute is the shim-introduced PBUFFER bit, not alpha, depth, stencil,
samples, renderable type, a combined-mask corner case, or a subsurface.

Raw evidence is preserved beside this report:

- `qwl-strict-no-shim.log`
- `qwl-strict-production.log`
- `qwl-chained-production-swap-egl.log`
- `egl-config-matrix.log`
- `qwl-minimal.cpp`
- `egl-config-matrix.c`

## Production 1.0.4 validation

The package was installed at about 19:01 CST. Only
`plasma-plasmashell.service` was restarted: Plasmashell changed from PID 2260 to
4016607, while KWin remained PID 1675. The new service environment contains
`LD_PRELOAD=` and retains the gsgpu EGL vendor selection and OpenGL QSG backend.

Checks on the new Plasmashell PID:

```text
gsgpu-egl-window-compat mappings=0
gsgpu_dri.so mappings=4
libEGL_gsgpu mappings=4
llvmpipe/swrast mappings=0
Cannot find EGLConfig=0
Non-blocking swap buffers not supported=0
EGL_BAD_CONFIG=0
EGL_BAD_SURFACE=0
```

KWin still reports `Compositing is active` and
`OpenGL renderer string: LoongGPU(TM) LG110 (...)`. A subsequent `vkcube --c 1`
returned 0. Production `/usr/lib/vkgl/libvkgl.so` remains SHA-256
`78c963855189836046520f1ee9f327057bd61d7a75c2b8e40b8988f3ea473668`.

The packaged KWin binaries were kept byte-for-byte identical to the previously
validated installed versions:

```text
kwin-dmabuf-bridge.so  10eb168a6b05e4b658e03d3c641c9de37662480bd1bc67025b1bf85a2b8e1a1d
kwin-drm-fd-reuse.so   4ae92c521c1a1e0ac923c1faee949b8c0e760abe76211c02b26b32f241bb3a3d
```

Package: `plasma-loonggpu-compat_1.0.4-1_loongarch64.deb`.
Deb SHA-256: `2db5b5c21cd93eab9997e25fbd2593e56a9c2aa263c4340790be378b23aad505`.

This is a targeted Plasma EGL correction, not completion of native Vulkan,
REL2 acceptance, or the larger LoongArch/AOSC objective.
