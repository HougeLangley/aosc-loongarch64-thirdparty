# Linux 7.3.4 gcc-O3 实机验收

日期：2026-11-14
目标：LoongArch（LA664，LG110），AOSC OS，16K pages，PREEMPT_RT，gcc-O3。

## 产物

- 内核：`7.3.4-mainline-16k-rt-gcc-o3`，`#1 SMP PREEMPT_RT Sat Nov 14 01:47:10 CST 2026`
- 编译：GCC 16.2.0 / GNU ld 2.47
- 配置：`CONFIG_CC_IS_GCC=y`、`CONFIG_LTO_NONE=y`、`CONFIG_PREEMPT_RT=y`、`CONFIG_PAGE_SIZE_16KB=y`
- kernel deb SHA-256：`2b91a94d42e636651410463aeb8098ae3f3752192e58b555c6162a4f7db58cd4`
- headers deb SHA-256：`b45acae18cd3a35274321cf773debd43acf24f29544e8742177c512e24d4725c`
- vmlinuz SHA-256：`640fd322ee8315e594710a4e863cadee9f0988b8b1616904af6140f1f5c14067`
- initramfs SHA-256：`8c2e4b1cbaef9ef4fbb7b6197ff54315eb7f870055afdfeb479e207d790cd171`

## 实机验收

gcc 7.3.4 已安装、进入 GRUB、实际启动；自动电池 PASS：

- `verify-kernel.sh`：8/8 PASS
- vkgl 官方 5 项：5/5，0 validation，GPU-only
- 1080p FIFO：vertex 41、texture 43、shading 41、effect2d 19、desktop 41 FPS
- 640×480 测试：vertex 372、texture 253、shading 288、effect2d 100、desktop 182 FPS（该组与 clang 历史样本背景负载不同，不作直接性能对比）
- DKMS loonggpu 为 gcc 内核构建成功；initramfs 含 `loonggpu.ko` + `la_ow_syscall.ko`

## 发布

kernel/headers deb 已发布到第三方 AOSC 仓库。发布后索引共 **29** 个 deb，
clang/gcc 两个 7.3.4 变体均在 README 列出；本机 apt 候选优先级 500，headers 可下载。

## GRUB

- 顶层 index0：7.3.4 clang-full-LTO
- 顶层 index1：7.3.4 gcc-O3
- 当前 `saved_entry` 仍为 clang；gcc 通过一次性启动验证，两个变体可共存。
