# 构建环境与流程

## 依赖

```bash
sudo apt install gcc g++ make cmake meson ninja pkg-config git curl \
                 pkg-config libdrm wayland mesa vulkan-headers \
                 go nodejs yarn python-3
```

- `vkgl-loonggpu` 需要 **SPIRV-Cross**（默认从 `/usr` 找静态库；也可设置 `SPIRV_CROSS_DIR`）：

```bash
git clone --depth 1 https://github.com/KhronosGroup/SPIRV-Cross.git
cmake -S SPIRV-Cross -B SPIRV-Cross/build -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DSPIRV_CROSS_STATIC=ON -DSPIRV_CROSS_CLI=OFF
cmake --build SPIRV-Cross/build -j4
```

## 逐包计划

全部当前配方的版本、来源、真实依赖、CHKUPDATE、构建路线、验证命令及硬件边界见
[PACKAGE-BUILD-PLANS.md](PACKAGE-BUILD-PLANS.md)。

## 轻量 self 单包（受限）

```bash
./scripts/build-package.sh packages/graphics-drivers/vkgl-loonggpu
```

只有逐包计划标为“轻量 self 可用”的配方才能走此路线：必须是 loongarch64、具有
`autobuild/build` 的 `ABTYPE=self`，且不带 `EPOCH`、不是 `ABHOST=noarch`。

脚本会：

1. **source** `spec` 与 `autobuild/defines`；
2. 在临时目录设置 `SRCDIR` 与 `PKGDIR`；仅对 `dir::` 自动复制包内文件，其他
   `SRCS` 的下载、校验和解包均由 `autobuild/build` 自己负责；
3. 直接执行 `autobuild/build`，**不运行完整 Autobuild4 模板及 prepare/beyond 等生命周期**；
4. 用 defines 元数据生成 `control`，硬编码 `Architecture: loongarch64`，版本只有
   `${VER}-${REL}`，**不会保留 `EPOCH`**；
5. 用 `dpkg-deb --build` 直接打包，产物放在 `build/<pkgname>_<ver>-<rel>_loongarch64.deb`。

因此它不是通用 fetcher 或完整 Autobuild4 替代品。带 EPOCH、noarch、模板 ABTYPE、
缺少自定义 build 的配方必须走 Ciel-ACBS；内核使用独立流程。

## Ciel-ACBS / Autobuild4（权威路线）

在已更新的 BuildKit 中，把本仓库 `packages/` 作为配方树，从仓库根目录按包名构建：

```bash
ciel build -i main <PKGNAME>
```

该路线负责通用源码获取与校验、模板构建、EPOCH/noarch 和完整 Autobuild 生命周期。
`ABTYPE=self` 也可在 Ciel-ACBS 中做权威复现；轻量构建器通过不代表可跳过安装测试。

## 注意事项

- 架构字段必须是 `loongarch64`（不是 `loong64`），否则 apt 不认。
- 依赖写 AOSC 包名（`glibc` 而非 `libc6`），在 `PKGDEP` 中以空格分隔，不要预先写成 Debian `Depends` 的逗号串；轻量构建器生成 Debian `Depends` 时统一转换成逗号分隔。
- `plasma-loonggpu-compat` 的 KWin shim 用 `LD_PRELOAD` 注入。dmabuf 桥使用 KWin 6.7 私有 GraphicsBuffer ABI，重建时必须显式提供源码与生成头文件目录，不能依赖偶然的全局 `CPATH`：

  ```bash
  KWIN_SOURCE_DIR=/path/to/kwin-6.7.5 \
  KWIN_BUILD_DIR=/path/to/kwin-6.7.5/build-loonggpu \
    ./scripts/build-package.sh packages/desktop-plasma/plasma-loonggpu-compat
  ```

  只做 Plasma 配置重建时，可用 `KWIN_DMABUF_BRIDGE_BINARY=/usr/lib/loonggpu/kwin-dmabuf-bridge.so` 明确保留当前已验证桥；发布 1.0.4 即采用这一方式，两个 KWin 桥与旧安装版逐字节一致。
- 构建内核见 [KERNEL.md](KERNEL.md)，它不走 `scripts/build-package.sh` 的通用流程。

## 已知坑：命令行 `CFLAGS=` 会覆盖 Makefile 自带的 define

djb 风格和老式 Makefile 常把 `-DLIBDIR=... -DDEFAULT_DUPLEX=...` 这类宏写在自己的
`CFLAGS` 里。如果 formula 用

```ruby
system "make", "CFLAGS=-Wno-error=implicit-int ..."
```

显式传入 CFLAGS，make 会**忽略 Makefile 里的 CFLAGS**，这些 define 全部丢失，表现为
`'LIBDIR' undeclared` / `You must compile with -D_REENTRANT` / `bcd.h: No such file`。

正确做法（见 `packages/` 里 `fq` 的处理）：

1. 优先把标志追加到 Makefile 自己的 `CFLAGS` 行（保留原有 define）；
2. 如果必须传命令行 CFLAGS，就把 Makefile 需要的所有 `-D` 和 `-I` 一起写进同一条命令行；
3. include 路径用 `Formula["<dep>"].opt_include`（keg-only 依赖不会自动进 CPATH）。

受影响的包：`fq`、`mpage`、`libowfat`、`tundra` 等。
