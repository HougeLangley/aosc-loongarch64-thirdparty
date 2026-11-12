# LG110 的 Wayland 兼容层

厂商栈（`loonggl` / `gsgpu`）能跑 OpenGL 2.1，但**不能**直接支撑 KWin：

1. 没有 `wl_drm` 全局（KWin 6.x 已移除）；
2. 第二个 `open("/dev/dri/card0")` 会拿到 master fd，DRM lease 失败，Xwayland 崩溃；
3. 扫描输出（scanout）在 16K 页下有 stride/tiling 问题。

`plasma-loonggpu-compat` 用两个 preload shim 解决 KWin 侧问题；Plasmashell 直接使用当前驱动的原生 WINDOW EGL 配置：

| shim | 注入进程 | 作用 |
|---|---|---|
| `kwin-drm-fd-reuse.so` | kwin_wayland | 复用 logind 授权的 card0 fd；对 lease 场景改用真实 `openat()` 取非 master fd；发布 legacy `wl_drm` 全局 |
| `kwin-dmabuf-bridge.so` | kwin_wayland | 拦截 `Display::bufferForResource`，把 `wl_drm` prime buffer 包装成 KWin `GraphicsBuffer`，走正常 EGL 导入 |

配套 systemd user drop-in 设置 `LD_PRELOAD`、`GBM_BACKEND=gsgpu`、
`__EGL_VENDOR_LIBRARY_FILENAMES`，并让 Plasmashell 在 KWin 就绪后启动。

内核侧由 `loonggpu` DKMS 提供扫描输出修复（见 `packages/kernel/.../autobuild/patches`）。

## 1.0.4：撤销错误的 WINDOW→PBUFFER 改写（2026-11-12）

独立 Qt 6.11.2 `QWindow + QOpenGLContext` 现场诊断和完整 EGLConfig 矩阵证明，当前驱动的 12 个配置全部为 `SURFACE_TYPE=WINDOW`，没有任何 PBUFFER 配置。Qt 默认请求在无 shim 时有 6 个匹配，原生 window surface、`makeCurrent`、`eglSwapInterval(0)` 和 swap 全部成功，renderer 为 LoongGPU LG110。

旧 `gsgpu-egl-window-compat.so` 把 WINDOW 改成 PBUFFER 后，每次选择都返回 0 个配置，继而产生 null config、`EGL_BAD_CONFIG` 和 `EGL_BAD_SURFACE`；`Non-blocking swap buffers not supported` 是后续结果。因此 1.0.4 从包和 Plasmashell 的 `LD_PRELOAD` 中移除该 shim，不修改 Qt 或 KWin 的两个 shim。该结论针对当前驱动配置表，不再沿用“厂商只提供 pbuffer”的历史假设。完整源码、原始日志和生产回归见 [EGL 诊断报告](../scripts/tests/plasma/egl-window-20261112.md)。

## 验证

```bash
qdbus org.kde.KWin /KWin supportInformation | grep -E "Compositing Type|OpenGL renderer"
# -> Compositing Type: OpenGL
# -> OpenGL renderer string: LoongGPU(TM) LG110 (...)
glxgears            # Xwayland 正常，~55 FPS
```
