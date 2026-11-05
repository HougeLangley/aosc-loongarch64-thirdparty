# aosc-loongarch64-thirdparty

**面向 AOSC OS / LoongArch64 的第三方软件源，以及让龙芯 3A6000（LoongGPU LG110）在 Wayland 下真正可用的驱动/兼容层集合。**

本仓库同时承担三件事：

1. **第三方 APT 源**：为 AOSC OS（LoongArch64）提供上游没有、或版本落后的软件包
   （Ruby、v2rayA、ZeroTier、KDE Plasma Wayland 兼容层、Vulkan ICD、主线 RT 内核）。
2. **可复现的构建配方**：沿用 [AOSC abbs](https://github.com/AOSC-Dev/aosc-os-abbs) 的
   `spec + autobuild/{defines,build,patches}` 目录结构，任何人可以按配方重新构建并核对结果。
3. **龙芯集成显卡（LG110）的 hack 记录**：厂商只提供 OpenGL 2.1/GLES2 的闭源用户态，
   没有 Vulkan、没有可用的 Wayland 合成路径。本仓库包含我们补上的全部内核态/用户态补丁与 shim，
   包括一个可用的 Vulkan ICD（[vkgl](packages/graphics-drivers/vkgl-loonggpu)）。

> 目标平台：龙芯 3A6000 + 7A2000 桥片（LG110 集成显卡），AOSC OS LoongArch64。
> 其他 LoongArch 机器（3A5000/3C5000 等）可以复用本仓库的大部分内容。

---

## 1. 使用第三方源

### 1.1 添加源与密钥

```bash
# 安装仓库签名公钥
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://homebrewloongarch64.site/aosc/key.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/aosc-loongarch64-thirdparty.gpg

# 添加源
echo "deb [signed-by=/etc/apt/keyrings/aosc-loongarch64-thirdparty.gpg] \
https://homebrewloongarch64.site/aosc stable main" \
  | sudo tee /etc/apt/sources.list.d/aosc-loongarch64-thirdparty.list

sudo apt update
```

### 1.2 安装软件

```bash
sudo apt install ruby              # Ruby 4.0（AOSC 主线仍是 3.4）
sudo apt install v2raya            # Web GUI 代理客户端（含 SQLite 修复）
sudo apt install zerotier-one      # ZeroTier 1.16
sudo apt install plasma-loonggpu-compat   # KDE Plasma Wayland + LG110 GPU 渲染
sudo apt install vkgl-loonggpu     # 可用的 Vulkan ICD（LG110，GPU 渲染）
```

安装 `vkgl-loonggpu` 后：

```bash
vulkaninfo --summary     # -> GPU0: LoongGPU LG110 (vkgl GLES2)
vkcube                   # 旋转的立方体，走 GPU
vulkanCapsViewer         # 能力浏览器，设备列表里可见 LG110
```

> `vkgl-loonggpu` 的 `postinst` 会把不能工作的 RADV ICD
> （`loonggpu_icd.loongarch64.json`）改名为 `.radv-disabled`，避免应用选到“能枚举但画不出东西”的设备。
> 卸载本包会自动恢复。

---

## 2. 包清单

| 包 | 分类 | 说明 | 状态 |
|---|---|---|---|
| `ruby` | runtime-ruby | Ruby 4.0.9，AOSC 主线版本过旧，`brew` 需要 | ✅ |
| `v2raya` | app-net | 上游 2.5.13-2，启用 SQLite，并在 RT 内核下默认使用原生 nftables | ✅ |
| `zerotier-one` | app-net | 上游 1.16.2 | ✅ |
| `plasma-loonggpu-compat` | desktop-plasma | KWin/Plasma 的 wl_drm、DRM lease、EGL 窗口兼容 shim | ✅ |
| `vkgl-loonggpu` | graphics-drivers | Vulkan 1.0 → GL 2.1 ICD 0.1.11；dmabuf 零拷贝、wl_shm 回退、5/5 GPU 回归 | ✅ |
| `mesa-vulkan-loonggpu` | graphics-drivers | RADV LG110 实验移植；**已废弃**，见第 5 节 | ⚠️ 仅存档 |
| `linux-kernel-mainline-16k-rt` | kernel | 主线 7.3.1 + AOSC 补丁 + 16K 页 + PREEMPT_RT；gcc -O3 桌面已验证，clang full-LTO 已构建、桌面验证中 | ✅ |

---

## 3. 仓库结构

```
aosc-loongarch64-thirdparty/
├── packages/                      # 按 AOSC abbs 分类组织的配方
│   ├── app-net/
│   │   ├── v2raya/{spec,autobuild/{defines,build}}
│   │   └── zerotier-one/
│   ├── runtime-ruby/ruby/
│   ├── desktop-plasma/plasma-loonggpu-compat/
│   │   ├── spec
│   │   ├── autobuild/{defines,build}
│   │   └── files/                 # shim 源码、systemd drop-in、会话启动器
│   ├── graphics-drivers/
│   │   ├── vkgl-loonggpu/{spec,autobuild,build,files/}
│   │   └── mesa-vulkan-loonggpu/  # 历史存档（RADV 移植）
│   └── kernel/linux-kernel-mainline-16k-rt/
│       ├── spec
│       ├── autobuild/{defines,build}
│       ├── autobuild/patches/     # loonggpu DKMS 适配补丁
│       └── files/                 # 打包脚本、诊断 initramfs 源码
├── scripts/
│   ├── build-package.sh           # 本地按配方构建（abbs 兼容）
│   ├── publish-debs.sh            # dists 布局发布 + gpg 签名 + 验证
│   └── check-updates.sh           # 上游版本检查（github/anitya）
├── docs/
│   ├── BUILDING.md                # 从零构建环境与依赖
│   ├── PUBLISHING.md              # 签名、索引、rsync、回滚
│   ├── KERNEL.md                  # 主线 RT 内核：AOSC 补丁、配置、LTO
│   ├── GPU-WAYLAND.md             # LG110 的 Wayland 兼容层原理
│   └── VULKAN.md                  # 为什么 RADV 不行、vkgl 怎么做的
└── repo/
    ├── key.gpg                    # 仓库签名公钥（ASCII armor 亦可）
    └── sources.list.d/aosc-loongarch64-thirdparty.list
```

---

## 4. 本地构建

本仓库的 `spec`/`autobuild` 与 AOSC abbs 兼容；也可以用自带的轻量构建器：

```bash
# 构建单个包（产物在 build/<pkg>/ 下）
./scripts/build-package.sh packages/app-net/v2raya

# 只生成 deb 而不安装
KEEP_STAGE=1 ./scripts/build-package.sh packages/graphics-drivers/vkgl-loonggpu
```

依赖：`gcc`、`g++`、`make`、`pkg-config`、`meson/ninja`（mesa）、`go`/`nodejs`/`yarn`（v2raya）、
`spirv-cross`（vkgl，或设置 `SPIRV_CROSS_DIR` 指向自建目录）。

更完整的说明见 [docs/BUILDING.md](docs/BUILDING.md)。

---

## 5. 为什么不能用 RADV（以及 vkgl 是什么）

龙芯 LG110 的**内核态**驱动是 amdgpu 的魔改分支（DKMS `loonggpu`），但它对外暴露的
**命令处理器接口不是 AMD PM4**，而是龙芯自己的 **GSPKT** 包格式：

```
GSPKT(op, n) = op & 0xff | (n & 0xffff) << 16
  GSPKT_NOP      0x80
  GSPKT_WRITE    0x81   (写寄存器/内存)
  GSPKT_INDIRECT 0x82   (执行 IB)
  GSPKT_FENCE    0x83
  ...
  GSPKT_DRAW     0x89   (文档未公开的绘制包)
```

我们做过直接实验（[`gspkt-probe`](docs/VULKAN.md)）：从用户态提交 `GSPKT_WRITE` 能真正写进显存，
说明 CS/VM 通路完好；而 RADV 提交的 PM4 命令流被 CP 静默丢弃——IB 被接受、fence 正常返回、
显存一个字节都没变。

因此：

* **RADV / mesa-vulkan-loonggpu 这条路线在 LG110 上不可能成功**（本仓库保留它仅作存档）。
* 我们的做法是 **vkgl**：把 Vulkan 1.0 翻译到厂商的 OpenGL 2.1 驱动上。
  - 用 EGL/GBM 离屏渲染，优先线性 dmabuf 零拷贝呈现，失败时逐图像回退 `wl_shm`；
  - SPIR-V 经 SPIRV-Cross 翻译成 GLSL 1.20（UBO 扁平化为 `uniform vec4 name[N]`）；
  - `gl_VertexID` 用顶点属性模拟；
  - Vulkan 的 Y 向下 NDC 与 GL 的 Y 向上约定通过“GL 行序直接写 wl_shm”抵消；
    但**背面剔除方向要翻转**（`glFrontFace(GL_CW)`），否则会看到立方体内壁。

能力边界：Vulkan 1.0 常用子集（无 compute / MRT / 实例化 / 时间戳），
`vkcube`、`vulkaninfo`、`vulkanCapsViewer` 以及简单 3D 应用可用；
DXVK / vkd3d / 重度游戏仍不具备条件。详见 [docs/VULKAN.md](docs/VULKAN.md)。

---

## 6. 内核

`packages/kernel/linux-kernel-mainline-16k-rt` 构建主线内核，要求：

* 上游最新稳定版（当前 7.3.1）；
* **AOSC OS 的 LoongArch 补丁全部打上**（450 个补丁中可应用的 355 个 + 55 个上游已合并；
  其余 40 个为 RISC-V/x86/Surface/Rust 等无关补丁）；
* 16K 页 + `PREEMPT_RT`；
* 两个变体：`gcc`（`KCFLAGS=-O3`）与 `clang`（`LLVM=1` + `CONFIG_LTO_CLANG_FULL`）；
* 打包为 AOSC 风格 `loongarch64` deb，含 DKMS 钩子（`loonggpu` 显卡驱动会随内核自动重建）。

```bash
sudo apt install linux-kernel-mainline-16k-rt-7.3.1-gcc-o3
sudo apt install linux-kernel-mainline-16k-rt-7.3.1-clang-lto
```

细节（补丁应用结果、LTO 与 ftrace 的取舍、DKMS 注意事项）见 [docs/KERNEL.md](docs/KERNEL.md)。

---

## 7. 发布

```bash
# 1) 校验索引与签名
./scripts/publish-debs.sh --dry-run build/*.deb
# 2) 收编 pool、重建 dists/Packages、签名 InRelease，并 rsync 到服务器
./scripts/publish-debs.sh --deploy build/*.deb
```

发布器会做四件事：pool 原子收编 → `dists/stable/main/binary-loongarch64/Packages(.gz)` 重建 →
用既有仓库身份重新签发 `Release`/`InRelease` → 本地/远端 MD5、HTTPS、隔离 apt 三重验证。
详见 [docs/PUBLISHING.md](docs/PUBLISHING.md)。

---

## 8. 与 AOSC OS 的关系

* 配方格式、目录约定、打包工具的很多经验来自 [AOSC OS abbs](https://github.com/AOSC-Dev/aosc-os-abbs)，
  内核补丁直接取自其 `runtime-kernel/linux-kernel` 包，谨致谢意。
* 本仓库**不是** AOSC OS 官方仓库，包内签名与维护责任由本仓库承担。
* 若某个包已被 AOSC 官方收录且版本不落后，本仓库会将其移除，避免与官方源冲突。

---

## 9. 许可

* 构建脚本、shim、vkgl：MIT（见 [LICENSE](LICENSE)）。
* 各上游软件包遵循其自身许可证；`packages/*/autobuild/patches/` 中的补丁来自 AOSC OS 或上游，
  版权归原作者所有。
