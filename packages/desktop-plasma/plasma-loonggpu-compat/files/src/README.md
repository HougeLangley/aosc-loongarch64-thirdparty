# Plasma LoongGPU compatibility

`kwin-drm-fd-reuse.so` is preloaded only into kwin_wayland. It:
- redirects the vendor EGL driver's premature card0 open to renderD128;
- reuses logind's authorized card0 FD for later KMS opens;
- advertises the EGL GBM platform and AR24/XR24 dma-buf query API used by KWin 6.7;
- publishes the legacy wl_drm authentication interface required by the vendor Mesa 18.3 Wayland EGL.

Qt Quick remains on the OpenGL RHI backend. Plasmashell no longer preloads an
EGL config rewrite: the current driver exposes WINDOW-only configurations, and
the historical WINDOW-to-PBUFFER shim caused `Cannot find EGLConfig`.

## 1.0.4 (2026-11-12)

Remove `gsgpu-egl-window-compat.so` from the package and from Plasmashell's
`LD_PRELOAD`. An independent Qt 6.11.2 Wayland test and a complete EGL config
matrix found 12 WINDOW configs and zero PBUFFER configs. Without the shim, six
configs match Qt's default request and native window surface creation,
makeCurrent, swapInterval(0), and swap all succeed on LoongGPU LG110. With the
old shim, every rewritten PBUFFER request returns zero configs. KWin's two shims
are unchanged.

## 1.0.3 (2026-11-03)

`kwin-drm-fd-reuse`: when the reused card0 FD is the DRM master, open the node
again and hand KWin the resulting non-master FD.  `DrmGpu::createNonMasterFd()`
needs it for DRM leasing; previously it received a dup of the master FD,
`drmDropMaster()` failed with EPERM, KWin posted an invalid `drm_fd` to Xwayland
and Xwayland crashed in a loop.  Verified: Xwayland runs, glxgears reaches
56 FPS on screen, no more `error marshalling arguments for drm_fd`.
