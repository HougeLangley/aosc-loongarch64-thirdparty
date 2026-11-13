# 主线 16K RT 内核

## 2026-11-13：7.3.4 隔离候选已编译，尚未启动验收

当前 `spec` 已跟进 kernel.org stable **7.3.4**。下方未特别注明版本的构建/发布记录仍是
7.3.1 历史记录，尤其 REL2 仍待原一次性启动项验收，不能因新候选编译成功而替换它。

7.3.4 候选的隔离构建使用 AOSC stable `b431925baa06056e4411c3a514d62122dd9db1f7`，
原始补丁结果为 `349 applied / 58 already / 42 conflict / 1 skipped`，不是“450 个全部应用”。
关键 Loongson/DRM 冲突已保留上游较新的实现；新增本地 0006 修复 AOSC fuzz 造成的 HID
错位，0007 完成 MEI 设备 ID 转换。`make -j1 LLVM=1 all` 真实返回 0，生成 6383 个模块；
16K、PREEMPT_RT、Clang full-LTO 和 LLD 均保持。候选内核与 headers deb 已生成；
loonggpu 已使用该 headers deb 隔离构建成功（`dkms_build_rc=0`，模块 vermagic 为
`7.3.4-mainline-16k-rt-clang-lto`）。root 在候选路径生成的 initramfs 无权限警告，
`lsinitrd` 已确认同时包含 `updates/dkms/loonggpu.ko` 和 `la_ow_syscall.ko`。
上述模块尚未加载，候选尚未启动验证；未安装、未发布、未改 GRUB。详细证据保留在
`/home/houge/infra/kernel-7.3.4-clang-lto/`。

### 2026-11-13 17:52 最新状态复验

- kernel.org stable 仍为 **7.3.4**，与本地 recipe 相同，不触发新构建。
- AOSC stable 已从候选固定提交 `b431925` 前进到 `1455c7a`，但差异不含任何
  kernel/linux/DRM 路径；历史 450 项补丁审查仍有效，不能宣称“补丁已随上游全部更新”。
- 两个 deb 和 initramfs 的 SHA-256 重新实测为：kernel `cd75bf73…4e50`、headers
  `1cbe0e39…7d01`、initramfs `c3eef5f4…5947`。
- loonggpu DKMS 对新 headers 的构建为 rc=0，模块 SHA `a5450bb9…e754`，vermagic
  精确匹配候选。隔离源码与已安装 `loonggpu-kernel-dkms 2:1.0.2+lnd25.1-3` 的
  210 个源文件逐一 SHA-256 相同（0 缺失/0 差异），因此不是用未知旧源码冒充。
  initramfs 内模块 SHA 因 dracut 裁剪 debug/symtab 而不同，但 `.text`、
  `.rodata`、`.modinfo` 与构建产物逐字节一致，`srcversion` 也相同，**不是旧模块**。
- 这只证明编译期兼容。真实启动、RT/NUMA/cpufreq、loonggpu 加载、DMA-BUF 与
  Wayland 合成仍未验证；候选没有安装到 `/boot`，APT 索引里没有 7.3.4 deb。

第三方开源 gsgpu 的 7.3.4 隔离 compile/MODPOST 研究见
[`packages/kernel/gsgpu-research`](../packages/kernel/gsgpu-research/README.md)。
该研究补丁不是生产 loonggpu 的替代品，不发布 KO/deb；缺少可用硬件 reset 原语且 PCI ID 相同，
仍禁止与生产驱动同时 probe。phase5 已隔离研究名称/裸导出，并要求严格 `exp_hw_support=1`。

## 目标

| 变体 | 编译器 | 优化 | 说明 |
|---|---|---|---|
| `gcc-o3` | gcc 16.2 | `KCFLAGS=-O3` | 完整 ftrace/调试能力 |
| `clang-lto` | clang 22.1 | `CONFIG_LTO_CLANG_FULL` | 关闭 function tracer（见下） |

两者共同点：

- 上游 7.3.1 源码；
- AOSC OS `runtime-kernel/linux-kernel` 的全部补丁（450 个）；
- AOSC 的 `autobuild/loongarch64/config.16k` 作为配置基线；
- `CONFIG_PAGE_SIZE_16KB=y`、`CONFIG_PREEMPT_RT=y`；
- 内核 release 名分别为 `7.3.1-mainline-16k-rt-gcc-o3` / `7.3.1-mainline-16k-rt-clang-lto`，
  可以共存，DKMS 会为各自构建 `loonggpu`。

## 补丁应用结果（7.3.1）

```
applied=355  already-upstream=55  conflict=40
```

40 个冲突全部是非 LoongArch 补丁（RISC-V/SpacemiT、x86、Surface、Rust 工具链等），
LoongArch 相关的 `AOSCOS-loongarch-*` 系列（0369–0374）全部应用成功；
`i2c-ls2x-v2`（2K0300）在上游已存在。

复现：

```bash
./scripts/fetch-aosc-patches.sh /path/to/linux-7.3.1
# 等价于：
#   git clone --depth 1 --filter=blob:none --sparse -b stable AOSC-Dev/aosc-os-abbs
#   git sparse-checkout set runtime-kernel/linux-kernel
#   对每个 patch 依次 patch -p1 -N --fuzz=5
```

本仓库另外收录以下让 gcc-O3 / clang full-LTO 变体正确构建和运行的修复
（`packages/kernel/.../autobuild/patches/`）：

| 补丁 | 原因 |
|---|---|
| `0001-loongarch-legacy-boot-strict-prototypes.patch` | AOSC 的 `acpi_arch_init (){` 缺 prototype，clang `-Werror=strict-prototypes` |
| `0002-loongarch-ow-syscall-no-lto-for-feat-test.patch` | `feat_test.o` 要被 `$(OBJDUMP)` 读，full-LTO 下是 bitcode，需 `-fno-lto` |
| `0004-mt7921-txpwr-heap-allocation.patch` | clang full-LTO 链接时 `mt7921_txpwr()` 栈帧 4016 B 超过 `-Wframe-larger-than=2048`，改为 kzalloc |
| `0003-gpio-xilinx-init-state-for-O3.patch` | `-O3` 下 gcc 发现 `xgpio_get()` 用未初始化的 bitmap 做读改写（`-Werror=uninitialized`），补 `bitmap_zero()` |
| `0005-loongarch-ow-syscall-lto-kprobe-addr.patch` | full LTO 可能内联 `kallsyms_lookup_name()`，改用首个 kprobe 已解析的地址；增加不写系统调用表的 `discovery_only` 安全验证模式 |
| `0006-repair-aosc-hid-fuzz-placement.patch` | 7.3.4 的 AOSC fuzz 把 HID notifier/quirk 代码插入错误函数和 `if` 表达式，恢复语法与生命周期 |
| `0007-complete-aosc-mei-pci-device-data.patch` | 完成 AOSC 0427 未应用的 MEI ICP LP3 设备 ID 转换，移除旧宏与重复设备项 |

## 配置

```bash
cp aosc-os-abbs/runtime-kernel/linux-kernel/autobuild/loongarch64/config.16k .config
scripts/config --enable PREEMPT_RT --disable PREEMPT_NONE --disable PREEMPT_VOLUNTARY
scripts/config --set-str LOCALVERSION "-mainline-16k-rt-gcc-o3"
make olddefconfig
```

clang 变体还需要（必须先用 `LLVM=1` 跑一次 olddefconfig，让 `CC_IS_CLANG` 生效）：

```bash
make LLVM=1 olddefconfig
scripts/config --enable LTO --enable LTO_CLANG --enable LTO_CLANG_FULL
scripts/config --set-str LOCALVERSION "-mainline-16k-rt-clang-lto"
make LLVM=1 olddefconfig
```

### 为什么关掉 function tracer

内核 Kconfig 中：

```
config HAS_LTO_CLANG
	depends on !FTRACE_MCOUNT_USE_RECORDMCOUNT
```

LoongArch 上 clang **不支持** `-mrecord-mcount`（实测报错），所以只能走 recordmcount，
而 recordmcount 与 LTO 对象不兼容。要拿到 full LTO，只能关闭 `FUNCTION_TRACER`
（`DYNAMIC_FTRACE` 随之消失）。这是有意的取舍：`clang-lto` 变体没有 ftrace，
需要 ftrace 时请用 `gcc-o3` 变体。

## 构建

```bash
# gcc
make -j1 KCFLAGS="-O3" all
# clang
make -j1 LLVM=1 all
```

`-j1` 是刻意的（机器资源有限，且要保证日志可复现）。

## 打包与安装

`files/package-kernel-v3.sh <gcc-o3|clang-lto>` 会：

1. `make modules_install` 到 staging；
2. 拷贝 `vmlinuz`、`System.map`、`.config`；
3. 生成 `postinst`（`depmod` → `dkms autoinstall` → `dracut`）、`prerm`、`postrm`；
4. 输出 kernel deb 与 headers deb。

```bash
sudo dpkg -i linux-kernel-*_loongarch64.deb linux-headers-*_loongarch64.deb
```

`postinst` 会自动为当前内核构建 DKMS 的 `loonggpu` 显卡驱动；首次安装后建议
`dracut -f` 再重启。

## 启动验证

- 一次性启动项：`grub-reboot <entry>`，失败后自动回退 `saved_entry`；
- 看 `/proc/version` 区分编译器（`gcc version` vs `clang version`）；
- 看 `uname -r` 区分变体；
- 图形验证：`qdbus org.kde.KWin /KWin supportInformation | grep renderer` 应显示 LG110。

### 2026-11-05 clang-LTO 桌面验证

- 实际运行 `7.3.1-mainline-16k-rt-clang-lto`，clang/LLD 22.1.8，16K 页、`SMP PREEMPT_RT`。
- 首次启动的 `ring xdma0 timeout` 已定位为 DKMS TTM DRM-buddy 路径读取未初始化的游标/页内偏移；
  clang 会把临时 GTT 的映射页数折成 0。修复见 `packages/graphics-drivers/loonggpu-dkms/` 的 0004。
- 修复后本次启动无 XDMA timeout/GPU reset；KWin 与嵌套 Weston 的 GL renderer 均为
  `LoongGPU(TM) LG110 (...clang-lto...)`，Plasma/Weston 映射 gsgpu，无 llvmpipe/swrast。
- vkgl dmabuf vkcube 也已在 clang 会话运行。一次性验证服务完成后自动禁用，GRUB 保留 gcc-O3 回退。
- 当前 clang 内核 deb 强依赖 `loonggpu-kernel-dkms >= 2:1.0.2+lnd25.1-3`；postinst 不再忽略
  DKMS 错误，并硬校验 initramfs 内存在 `updates/dkms/loonggpu.ko`。

### 2026-11-12 REL2 候选构建仍待启动验收

上一节是历史 clang 会话验证，不等同于当前 REL2 候选已验收。新的 REL2 本地构建身份为
`#2 SMP PREEMPT_RT Sun Nov  8 21:56:09 CST 2026`，release 为
`7.3.1-mainline-16k-rt-clang-lto`，`/boot` 映像 SHA-256 为
`6eec098be14b8c9462062135b73e39808cd9612114f6bc0a9daae6f23cc9c386`。
截至 2026-11-12 18:30，机器仍运行 REL1（`#1`，2026-11-04），REL2 的 GRUB 一次性启动项已武装，
但新 boot ID、initramfs 模块、真实 LibLoL 可执行、Wayland vkcube、KWin 硬件合成、loonggpu/DRM、
ftrace、DKMS 和 systemd failed units 尚未在同一 REL2 启动中全部通过。因此不得把 REL2 描述为已发布；
验收通过前也继续冻结系统更新，保留 gcc-O3 回退。

## 实际落地的 LoongArch 相关补丁（48 个）

在 7.3.1 上最终成功应用、且与 LoongArch/龙芯平台直接相关的补丁：

  - `0004-UPSTREAM-MIPS-Loongson64-dts-Add-node-for-LS7A-PCH-L`
  - `0021-FROMLIST-LoongArch-Update-the-flush-cache-policy`
  - `0026-FROMLIST-PCI-Prevent-LS7A-Bus-Master-clearing-on-kex`
  - `0033-FROMLIST-RFC-drm-amdkfd-disable-HSA_AMD_SVM-on-Loong`
  - `0065-BACKPORT-FROMLIST-LoongArch-detect-and-disable-sc.q-`
  - `0182-FROMLIST-pci-loongson-Avoid-L0s-on-LS7A1000-PCIe-x8-`
  - `0184-FROMLIST-can-Add-Loongson-CAN-FD-controller-driver`
  - `0185-FROMLIST-can-loongson_canfd-Add-RXDMA-support`
  - `0186-FROMLIST-gpio-loongson-64bit-Add-back-the-support-fo`
  - `0189-FROMLIST-cpufreq-loongson3-Make-this-driver-depend-o`
  - `0190-FROMLIST-cpufreq-loongson3-Adjust-the-width-of-id-an`
  - `0191-FROMLIST-cpufreq-loongson3-Replace-per-package-mutex`
  - `0192-FROMLIST-cpufreq-loongson3-Use-global-physical-CPU-I`
  - `0193-FROMLIST-cpufreq-loongson3-Replace-IOCSR-read-write-`
  - `0202-FROMLIST-MIPS-Loongson-Add-board_ebase_setup-support`
  - `0203-FROMLIST-MIPS-Loongson64-Enlarge-cross-package-node-`
  - `0206-LOONGSON-LoongArch-Add-CPU-HWMon-platform-driver`
  - `0207-LOONGSON-drivers-firmware-Move-sysfb_init-from-devic`
  - `0208-LOONGSON-drm-radeon-Workaround-radeon-driver-bug-for`
  - `0264-DEBIAN-Use-RELAXED-ieee754-mode-for-Loongson-3-as-3A`
  - `0297-BACKPORT-DEEPIN-pci-quirks-LS7A2000-Fix-pm-transitio`
  - `0367-AOSCOS-loongarch-re-introduce-add_numamem_region-ini`
  - `0368-AOSCOS-loongarch-basic-boot-support-for-legacy-firmw`
  - `0369-AOSCOS-loongarch-parse-BPI-data-and-add-memory-mappi`
  - `0370-AOSCOS-loongarch-add-MADT-ACPI-table-conversion`
  - `0371-AOSCOS-loongarch-correct-missing-offset-of-PCI-root-`
  - `0372-AOSCOS-loongarch-fix-missing-dependency-info-in-DSDT`
  - `0373-AOSCOS-loongarch-fix-DMA-address-offset`
  - `0374-AOSCOS-loongarch-fix-HT_RX_INT_TRANS-register`
  - `0375-AOSCOS-arch-loongarch-add-la_ow_syscall-as-in-tree-m`
  - `0378-AOSCOS-MIPS-Temporarily-disable-Loongson3-LL-SC-erra`
  - `0384-AOSCOS-MIPS-loongson64-deselect-ARCH_SUPPORTS_HUGETL`
  - `0395-AOSCOS-MIPS-Loongson-Add-constant-timer-support`
  - `0396-AOSCOS-MIPS-loongson64-fix-constant-timer-build-on-k`
  - `0397-AOSCOS-MIPS-loongson64-use-generic-vDSO-clock-mode-s`
  - `0398-AOSCOS-MIPS-Loongson-Add-PMON-read-write-in-OS-suppo`
  - `0400-AOSCOS-MIPS-math-emu-replace-CPU_LOONGSON3-condition`
  - `0402-AOSCOS-memset-optimization-for-loongson-3`
  - `0403-AOSCOS-MIPS-loongson3-memset-replace-asm-export.h-wi`
  - `0404-AOSCOS-MIPS-loongson3-memset-use-PTR_WD-to-fix-build`
  - `0406-AOSCOS-memcpy-optimization-for-loongson-3`
  - `0407-AOSCOS-MIPS-loongson3-memcpy-use-PTR_WD-to-fix-build`
  - `0408-AOSCOS-MIPS-loongson3-memcpy-replace-asm-export.h-wi`
  - `0409-AOSCOS-MIPS-mark-CPU_LOONGSON64-as-HAVE_PLAT_MEMCPY`
  - `0410-AOSCOS-MIPS-loongson3-memcpy-adapt-to-RAW_COPY_USER`
  - `0411-AOSCOS-spi-spi-loongson-allow-building-on-MACH_LOONG`
  - `0419-AOSCOS-MIPS-Loongson-Salvage-the-full-count-from-the`
  - `0441-AOSCOS-mmc-loongson2-add-back-the-so-called-ABI-1.0-`

其余 307 个成功应用的补丁为通用修复（网络 PHY、PCI、USB、drm 等），
55 个已被上游合并，40 个冲突补丁均与 LoongArch 无关（RISC-V/SpacemiT、x86、
Surface、Rust 工具链）。

## 外部模块（DKMS）前置条件

内核 headers 包必须包含 **`tools/objtool/objtool`**，否则任何 DKMS 模块构建都会失败：

```
/bin/sh: /usr/src/linux-headers-<rel>/tools/objtool/objtool: No such file or directory
```

`package-kernel-v2.sh` / `package-kernel-v3.sh` 的 headers 段已经改为
`include scripts tools/build tools/objtool tools/bpf`，把该二进制一起打包。

`loonggpu` 的 tracepoint 告警（`unsafe pointer field 'ring_name'`）修复见
`packages/graphics-drivers/loonggpu-dkms/`。

## 变体共存

`gcc-o3` 与 `clang-lto` 的包名、`/boot` 文件名、`/lib/modules/<release>` 目录、
`/usr/src/linux-headers-<release>` 路径都带变体后缀，因此**两个内核可以同时安装**，
在 GRUB 里选择启动即可做 A/B 对比；打包脚本不再声明 `Conflicts`。
