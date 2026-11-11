# loonggpu-dkms 补丁

AOSC 的 `loonggpu-kernel-dkms` 包把厂商源码装到 `/usr/src/loonggpu-1.0.2`，
本目录存放发给它的补丁（不是内核补丁）。

| 补丁 | 作用 |
|---|---|
| `patches/0006-preserve-scanout-preferred-domain.patch` | 保留已成功scanout pin验证的domain，避免KWin GBM framebuffer在render CS中由VRAM迁回GTT、下一次page flip又迁回VRAM。allowed_domains、失败路径及跨GPU共享强制GTT均不变。 |
| `patches/0005-linux-7.3-wayland-dc-compat.patch` | 汇总本机已验证的 Linux 7.2/7.3 API 与 Wayland DC 修复：`drm_atomic_commit` 类型迁移、`vma_is_cow_mapping`、`dma_fence_array_create` 参数变化，以及 GBM 私有 tiling/primary stride 同步。 |
| `patches/0004-ttm-buddy-cursor-init.patch` | 修复 DRM buddy TTM 复制的真实未初始化 UB：每轮从 `src_mm/dst_mm.start` 计算地址与页内偏移，按偏移限制 XDMA 复制长度，并给临时 GTT 窗口补页内偏移。原 clang 模块会把临时 GTT 映射页数优化成 0，导致 `ring xdma0 timeout`；非 buddy 路径保留原有单次偏移语义。 |
| `patches/0003-clang-kernel-support.patch` | 让厂商模块支持 **clang 编译的内核**：① `dkms` 调用时环境里没有 `CONFIG_CC_IS_CLANG`，改为从 `/lib/modules/$(KERNEL_UNAME)/build/.config` 判断，否则会用 gcc 编 clang 内核而报 `unrecognized option '-fexperimental-late-parse-attributes'`；② 新内核 `lg_drm_do_get_edid()` 返回 `const struct edid *`，clang `-Werror` 下需把局部变量改 const 并在 `drm_add_edid_modes()` 处显式转换。 |
| `patches/0002-workqueue-flags-unbound.patch` | `kcd_process_wq` 用 `alloc_workqueue(name, 0, 0)` 创建，7.x 内核会告警 `using neither WQ_PERCPU nor WQ_UNBOUND`；`KCD IH` 同样补 `WQ_UNBOUND`。 |
| `patches/0001-trace-ring-name-as-string.patch` | 把两个 tracepoint 里的 `char *ring_name` 改成 `__string(...)` + `__get_str()`。原写法是裸指针，新内核的 tracepoint 安全校验会在 dmesg 里报警：`event 'loonggpu_sched_run_job' has unsafe pointer field 'ring_name'`。 |

## 本地应用方式

```bash
cd /usr/src/loonggpu-1.0.2
sudo patch -p1 < /path/to/0001-trace-ring-name-as-string.patch
sudo dkms build loonggpu/1.0.2 -k "$(uname -r)" --force
sudo dkms install loonggpu/1.0.2 -k "$(uname -r)" --force
```

> 注意：`dkms install` 只更新 `/lib/modules/<rel>/updates/dkms/loonggpu.ko.zst`，
> 已加载的模块要重启（或卸载后重载）才会换成新版本。

## 另一个 DKMS 前置条件：objtool

内核开启 `CONFIG_OBJTOOL`/ORC 展开时，外部模块构建需要
`/usr/src/linux-headers-<rel>/tools/objtool/objtool`。本仓库的内核 headers
打包脚本已经把它包含进去（`package-kernel-*.sh` 里的 `tools/objtool`）。
缺少时 DKMS 会报 `/bin/sh: .../tools/objtool/objtool: No such file or directory`。

## 构建完整修订版 deb

本目录同时是 abbs 风格配方：`spec` 下载 AOSC 原始上游 deb，`autobuild/build`
依次应用 AOSC 的 49 个 `patches.deferred` 与本目录 6 个追加补丁。本地基础设施中运行：

```bash
bash ~/infra/scripts/abbs-lite.sh ~/infra/pkg/loonggpu-kernel-dkms
```

产物为 `loonggpu-kernel-dkms_1.0.2+lnd25.1-3_loongarch64.deb`（control 版本为
`2:1.0.2+lnd25.1-3`）。postinst 会为每个完整 headers 树构建模块；若旧 headers 的
objtool 已有动态库缺失则明确跳过，其他内核真实构建失败会在处理完所有内核、更新
initramfs 后统一报错，不会静默成功。clang-LTO 内核包要求至少此 DKMS 修订版。

## 0006 实机验证边界

在独立一次性initramfs中加载候选后，KWin继续使用gsgpu硬件渲染，19/19项vkgl公开
正确性测试通过；正确entry-kprobe只记录1次初始system→GTT迁移，未再记录原先反复出现的
9,830,400字节VRAM↔GTT整屏迁移。相同vkmark协议的顺序启动对照中，窗口shading中位数
123→263 FPS、vertex 195→343、texture 128→221，独立全屏shading 25→32 FPS；所有运行
启用Khronos validation，候选各组最小FPS均高于原模块该组最大值。后台Homebrew lane未停止，
结果不是交织AB或极限性能证明。候选先通过独立镜像验证，未使用会异常重启的活跃GPU
`rmmod`路径。
