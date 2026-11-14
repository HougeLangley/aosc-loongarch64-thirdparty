# 主线 16K RT 内核（当前 7.3.4）

> 只记录**当前发布版本**。旧内核的构建/对照记录留在本地证据与 git 历史，不在公开文档罗列。
> 当前第三方 AOSC 源索引共 29 个 deb；本文只涉及 4 个 7.3.4 内核/headers 包。

## 当前版本

| 变体 | release | 编译器 / 优化 | 关键配置 |
|---|---|---|---|
| clang-full-LTO | `7.3.4-mainline-16k-rt-clang-lto` | clang 22.1.8 / LLD，`CONFIG_LTO_CLANG_FULL=y` | 16K、PREEMPT_RT |
| gcc-O3 | `7.3.4-mainline-16k-rt-gcc-o3` | GCC 16.2 / GNU ld，`KCFLAGS=-O3` | 16K、PREEMPT_RT、`CONFIG_LTO_NONE=y` |

两变体可共存，DKMS 分别为各自构建 `loonggpu`。当前默认启动 clang，
`gcc-O3` 已实机启动验证并保留为 GRUB 备选。

## 发布物

| deb | 版本 | SHA-256 |
|---|---|---|
| `linux-kernel-mainline-16k-rt-7.3.4-clang-lto` | `7.3.4-1` | `cd75bf73bc2b502f74c2a12fdf23f04b88f2a28c2670334ada01f7d3dbdc4e50` |
| `linux-headers-mainline-16k-rt-7.3.4-clang-lto` | `7.3.4-1` | `1cbe0e39990aa4a5560f8bc83ee309c74a0ca66dfdd92bab696aebca7c6c7d01` |
| `linux-kernel-mainline-16k-rt-7.3.4-gcc-o3` | `7.3.4-1` | `2b91a94d42e636651410463aeb8098ae3f3752192e58b555c6162a4f7db58cd4` |
| `linux-headers-mainline-16k-rt-7.3.4-gcc-o3` | `7.3.4-1` | `b45acae18cd3a35274321cf773debd43acf24f29544e8742177c512e24d4725c` |

仓库：`https://homebrewloongarch64.site/aosc stable main`，签名 key
`https://homebrewloongarch64.site/aosc/key.gpg`。

```bash
sudo apt update
sudo apt install linux-kernel-mainline-16k-rt-7.3.4-gcc-o3 \
                 linux-headers-mainline-16k-rt-7.3.4-gcc-o3
# 或 clang 变体
sudo apt install linux-kernel-mainline-16k-rt-7.3.4-clang-lto \
                 linux-headers-mainline-16k-rt-7.3.4-clang-lto
```

## 构建来源

- 上游：kernel.org stable **7.3.4**。
- AOSC 补丁基线：`runtime-kernel/linux-kernel`，7.3.4 上
  `applied=349 / already-upstream=58 / conflict=42 / skipped=1`；
  42 个冲突集中在非 LoongArch 路径，不宣称“全部应用”。
- 配置：AOSC `config.16k` + `CONFIG_PAGE_SIZE_16KB=y` + `CONFIG_PREEMPT_RT=y`。
- 本地补丁：`packages/kernel/linux-kernel-mainline-16k-rt/autobuild/patches/`，
  含 boot strict prototypes、OW syscall LTO、mt7921 栈帧、gpio O3 初始化、
  kprobe 地址、HID fuzz 修复、MEI 设备 ID 修复。

## 验证

- clang 7.3.4：实机启动、自动电池 **18/18**、vkgl 严格矩阵 **13/13**、
  公开 `verify-kernel.sh` **8/8**。
- gcc 7.3.4：实机启动、`verify-kernel.sh` **8/8**、vkgl 公开测试 **5/5**。
- 二者均过 16K / PREEMPT_RT / loonggpu loaded / DKMS entry /
  KWin LG110 renderer / vkgl active。
- 公网 HTTPS 隔离 apt：`apt-get update` 成功，kernel/headers 7.3.4 可下载，
  SHA-256 与发布物一致；隔离 `apt-cache policy` 候选优先级 500。

公开验收：
[clang-full-LTO](KERNEL-7.3.4-VALIDATION.md) ·
[gcc-O3](KERNEL-7.3.4-GCC-VALIDATION.md)

## 已知边界

- 1080p 高负载且存在编译/内存压力背景时，`snd_hda_intel` 可能打印
  `stream 0 dma error: 0x28`；低载复测为 0，模拟音频正常，未出现 GPU reset，
  当前不作为 7.3.4 独有回归。
- gcc-O3 为已验证备选；默认仍 clang，`saved_entry` 不自动切换。
- 旧内核仅本地回退，不在公开文档展开，也不加入源索引。
