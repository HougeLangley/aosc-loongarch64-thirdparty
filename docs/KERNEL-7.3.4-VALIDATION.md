# Linux 7.3.4 clang-full-LTO 实机验收

日期：2026-11-13
目标：LoongArch（LA664，LG110），AOSC OS，16K pages，PREEMPT_RT，clang full-LTO。

## 产物

- 内核：`7.3.4-mainline-16k-rt-clang-lto`，`#1 SMP PREEMPT_RT Fri Nov 13 08:57:04 CST 2026`
- 编译：clang 22.1.8 / LLD 22.1.8
- 配置：`CONFIG_LTO_CLANG=y`、`CONFIG_LTO_CLANG_FULL=y`、`CONFIG_PREEMPT_RT=y`、`CONFIG_PAGE_SIZE_16KB=y`、`CONFIG_CC_IS_CLANG=y`、`CONFIG_LD_IS_LLD=y`
- 内核 deb SHA-256：`cd75bf73bc2b502f74c2a12fdf23f04b88f2a28c2670334ada01f7d3dbdc4e50`
- headers deb SHA-256：`1cbe0e39990aa4a5560f8bc83ee309c74a0ca66dfdd92bab696aebca7c6c7d01`
- vmlinuz SHA-256：`a2f3b59767452d5f4050b2ca52045c39758447b7edb82e0cfe7702dbed984168`
- initramfs SHA-256：`c9ec48491d5a6c0c28a7663d07523da82bb3820fa104c5a3f9504f35fbb9c459`

## 实机验收

7.3.4 已安装、进入 GRUB、实际启动，并成为默认启动项。自动电池 18/18 PASS：

- 精确构建身份、clang-lto release、LTO_CLANG/PREEMPT_RT/16KB
- 新 boot_id、镜像 SHA、initramfs SHA
- initramfs 含 `loonggpu.ko` + `la_ow_syscall.ko`
- LibLoL old-world 可执行
- vkgl 仅枚举 LG110，无 llvmpipe/lavapipe
- Wayland vkcube、KWin 硬件合成
- loonggpu DRM 节点、ftrace idle、DKMS installed
- 无 failed systemd units

vkgl 官方 5 项测试 5/5、0 validation errors、GPU-only；严格矩阵 13/13 PASS：

- dispatch lifetime、WSI semaphore、submit fence（含 GPU readback）
- format properties、sampler create、scissor
- vertex bindings、draw instance A/B
- UpdateBuffer vertex/uniform/indirect

## 性能对照

同一 rootfs、vkgl、LG110、KWin Wayland；暂停 Homebrew 与内核后台构建后，1080p FIFO 三轮中位：

| 场景 | 7.3.1 clang #2 | 7.3.4 clang #1 |
| --- | ---: | ---: |
| vertex | 38 | 38 |
| texture | 42 | 43 |
| shading | 40 | 41 |
| effect2d | 20 | 19 |
| desktop | 41 | 41 |

差异在噪声内，未发现 7.3.4 性能回退。GPU 时钟 `pm_dpm_sclk` 已在最高 496MHz 档，无提频空间。

## 已知边界

1080p 高负载且存在编译/内存压力背景时，`snd_hda_intel` 可能打印
`stream 0 dma error: 0x28`（FIFO_READY | FIFO_ERR）。低载复测为 0，模拟音频播放正常，
未出现 GPU reset；当前判定为负载相关 FIFO 噪声/硬件行为，不作为 7.3.4 独有回归。
后续若出现音频断流，再按回归流程处理。

## 发布

kernel/headers deb 已发布到第三方 AOSC 仓库；仓库共 27 个索引 deb，
签名、HTTPS、隔离 apt 验证通过。GRUB 默认 `saved_entry=7.3.4`，旧 7.3.1 保留在子菜单。

## 独立与客户端复核

- 仓库自带 `scripts/verify-kernel.sh` 在 7.3.4 上 **8/8 PASS**：16K/RT、clang full-LTO、loonggpu loaded、DKMS entry、KWin LG110 renderer、vkgl active。
- 公网 HTTPS 隔离 apt `apt-get update` 成功，下载 kernel/headers 7.3.4 成功，SHA-256 与发布物一致。
- 本机 `127.0.0.1:8080/aosc` 源刷新后候选优先级 500，`apt-get download` 成功；此前无候选只是 apt 索引未刷新。
