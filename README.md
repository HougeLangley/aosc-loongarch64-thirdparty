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
sudo apt install brew-ui-linux     # 非官方 Qt 6 Homebrew 图形管理前端
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

## 2. 最新 deb 包清单

<!-- BEGIN GENERATED DEB PACKAGE INDEX -->

以下清单由 `scripts/sync-readme-package-index.py` 从实际发布的
`dists/stable/main/binary-loongarch64/Packages` 生成，**只列每个包的最新版本**。
当前列出 **15 个最新 deb 条目、15 个不同包名**；索引共保留 19 个 deb。
旧版本只保留有限的回滚副本，不在 README 罗列。APT 默认选择可安装的最新版本。
`mesa-vulkan-loonggpu` 仍只是已废弃的 RADV 存档，不代表 LG110 可用原生 Vulkan。

| 软件包 | 版本 | 架构 | SHA-256 | deb |
|---|---|---|---|---|
| `brew-ui-linux` | `0.1.0-5` | `loongarch64` | `f31a56110f420390f32cb2f795b8984109f41187382cbd4cc7e374184c30f481` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/brew-ui-linux/brew-ui-linux_0.1.0-5_loongarch64.deb) |
| `greeter` | `0.2.0-1` | `loongarch64` | `e076fa0e64256c51c8fc8c749cde6375536825f501a4957362524410599cb05e` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/greeter/greeter_0.2.0-1_loongarch64.deb) |
| `hello` | `1.0.0-1` | `loongarch64` | `5394a85cc56c50e8ec5a2593c23089755fd376e786a1e09d2d97f25f7b443952` | [下载](https://homebrewloongarch64.site/aosc/pool/main/h/hello/hello_1.0.0-1_loongarch64.deb) |
| `linux-headers-mainline-16k-rt-7.3.1-clang-lto` | `7.3.1-1` | `loongarch64` | `acd18a1454e1a5a2ee2b51cb142e5cd7080c52bdcfb8c120b2f1649a51a5dd20` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/linux-headers-mainline-16k-rt-7.3.1-clang-lto/linux-headers-mainline-16k-rt-7.3.1-clang-lto_7.3.1-1_loongarch64.deb) |
| `linux-headers-mainline-16k-rt-7.3.1-gcc-o3` | `7.3.1-1` | `loongarch64` | `a37f12183c8b4bb52e342b41e255be62ef2566f4b7d3617b17cdb453c3712771` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/linux-headers-mainline-16k-rt-7.3.1-gcc-o3/linux-headers-mainline-16k-rt-7.3.1-gcc-o3_7.3.1-1_loongarch64.deb) |
| `linux-kernel-mainline-16k-rt-7.3.1-clang-lto` | `7.3.1-1` | `loongarch64` | `e8f63db9bb4e41c2abe1354b98a7afb037173a6b91cdaf21de585d0f5ac824fa` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/linux-kernel-mainline-16k-rt-7.3.1-clang-lto/linux-kernel-mainline-16k-rt-7.3.1-clang-lto_7.3.1-1_loongarch64.deb) |
| `linux-kernel-mainline-16k-rt-7.3.1-gcc-o3` | `7.3.1-1` | `loongarch64` | `b56f2e2d37fc2b9db45687f5ee6d064f3782fb875c085e4bb5fccc7088604988` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/linux-kernel-mainline-16k-rt-7.3.1-gcc-o3/linux-kernel-mainline-16k-rt-7.3.1-gcc-o3_7.3.1-1_loongarch64.deb) |
| `loonggpu-kernel-dkms` | `2:1.0.2+lnd25.1-2` | `loongarch64` | `004b62abaefa183e1aeb3fe4d828e46824d85c4b1d08aa99fa9f980570cbc728` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/loonggpu-kernel-dkms/loonggpu-kernel-dkms_1.0.2%2Blnd25.1-2_loongarch64.deb) |
| `mesa-vulkan-loonggpu` | `26.1.5-1` | `loongarch64` | `3543cc9ea848494b4a2238b212309c39a0a4f119c57e9318e3a843847322e10a` | [下载](https://homebrewloongarch64.site/aosc/pool/main/m/mesa-vulkan-loonggpu/mesa-vulkan-loonggpu_26.1.5-1_loongarch64.deb) |
| `plasma-loonggpu-compat` | `1.0.3-1` | `loongarch64` | `b2c1a945a155d4b72abd3c9a68f144cc89bf766ad5b48e5cbab648171322f766` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/plasma-loonggpu-compat/plasma-loonggpu-compat_1.0.3-1_loongarch64.deb) |
| `ruby` | `4.0.9-1` | `all` | `31eeca670cc0a5415b7a7265f8196573ef2285a2cc45b191a6bb48b4ca5a0ce1` | [下载](https://homebrewloongarch64.site/aosc/pool/main/r/ruby/ruby_4.0.9-1_all.deb) |
| `v2raya` | `2.5.14-1` | `loongarch64` | `5eaf29d7ffac7cfd0d0acee04576029bc19541cae309f32007783311021fbaae` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/v2raya/v2raya_2.5.14-1_loongarch64.deb) |
| `vkgl-loonggpu` | `0.1.34-1` | `loongarch64` | `f881c78245ec88335c59b49b845dbeb3d24e1d047f8e0771e773281074bb93b2` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/vkgl-loonggpu/vkgl-loonggpu_0.1.34-1_loongarch64.deb) |
| `vkmark` | `2025.01-4` | `loongarch64` | `5cbda2cb85b902f590b6fdf0d2e8ad4cd1f84887c8f27020b6596d6a5085356a` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/vkmark/vkmark_2025.01-4_loongarch64.deb) |
| `zerotier-one` | `1.16.2-1` | `loongarch64` | `a21e556042be743970ab9ac1a7f14c3d739e227007778b3d28bb1c4fe9ae39f4` | [下载](https://homebrewloongarch64.site/aosc/pool/main/z/zerotier-one/zerotier-one_1.16.2-1_loongarch64.deb) |

<!-- END GENERATED DEB PACKAGE INDEX -->

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
│   ├── HOMEBREW.md                # brew 7.0.13、双 lane 与 Linux GUI 维护
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
显存一个字节都没变。后续完整 IB 对照见 [descriptor-only](scripts/research/lg110/vktest-gradient-descriptor-differential.md)、[实际采样](scripts/research/lg110/vktest-gradient-sample-differential.md) 与 [texelFetch 前置失败](scripts/research/lg110/vktest-gradient-texel-fetch-differential.md)。

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
`texelFetch` 目前在 GLSL 编译前失败；实际硬件仅有 GLSL 1.20，且无 `GL_EXT_gpu_shader4`，不能靠强制扩展或 GLSL 130 修复。证据见 [兼容性报告](scripts/research/lg110/vkgl-texel-fetch-compatibility.md)。
顶点 stride 的原始 UAPI、属性敏感 A/B/A、shader 选择器及同步全 VA 差分见 [LG110 UAPI/全 VA 审计](scripts/research/lg110/lg110-vertex-state-uapi-all-va.md)：已测 GFX 与全部已映射 VA 均未携带该差异，尚未定位 vendor 内部派生路径，也不据此虚构原生字段。

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
详见 [docs/PUBLISHING.md](docs/PUBLISHING.md)。操作系统更新审查与回归记录见
[docs/MAINTENANCE.md](docs/MAINTENANCE.md)。

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
