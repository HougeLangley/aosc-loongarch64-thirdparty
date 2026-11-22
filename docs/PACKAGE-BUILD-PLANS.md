# 全配方包构建与验证计划

> 基于当前工作树 121 套 `spec` 纯文本生成；生成时间 UTC `2026-11-21T16:42:03.086856+00:00`。
> 本文是计划，不表示任何包已在本轮构建、安装或发布。依赖和来源按配方原文记录；`@AB_AUTO_*@` 等 Autobuild 宏由完整构建环境展开。

## 路线总原则

- **Ciel-ACBS/Autobuild4 是权威路线**：负责通用源码获取、校验、模板构建、EPOCH、noarch、依赖和完整 Autobuild 生命周期。
- **轻量 `scripts/build-package.sh` 只覆盖已验证的 loongarch64 `self` 子集**：它会 source 配方、执行 `autobuild/build` 并直接打 deb；除 `dir::` 外不通用 fetch，不运行完整 Autobuild 模板/prepare/beyond 生命周期，不保留 EPOCH，且硬编码 loongarch64。
- 每包先跑产物元数据与内容检查，再跑列出的 smoke；库、内核和硬件包不能用 `--version` 代替真实功能验证。
- 构建总说明见 [BUILDING.md](BUILDING.md)；内核详见 [KERNEL.md](KERNEL.md)；发布与 latest-only 清理见 [PUBLISHING.md](PUBLISHING.md)。

## 汇总

| 路线 | 包数 |
|---|---:|
| Ciel-ACBS | 100 |
| 轻量 self 可用 | 20 |
| 专用内核流程 | 1 |

- EPOCH 包：`loonggpu-kernel-dkms`=2:1.0.2+lnd25.1-3。
- noarch 包：`ansible`, `bashtop`, `bat-extras`, `btrbk`, `codespell`, `prettyping`, `pyenv`, `speedtest-cli`, `visidata`, `yamllint`。
- bmake 的更新策略由另一 P8 负责；本文件仍记录其当前真实字段，不擅自补齐。

## 通用构建命令（计划，未执行）

```bash
# Ciel-ACBS 权威路线，在仓库根目录和已更新 BuildKit 中执行。
ciel build -i main <PKGNAME>

# 仅下文标为“轻量 self 可用”的包：
./scripts/build-package.sh <PACKAGE_RECIPE_DIR>
```

## 逐包计划

### 1. `7-zip`

- **路径**：`packages/app-utils/7-zip`
- **VER-REL**：`26.06-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/$VER::https://github.com/ip7z/7zip`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`github::repo=ip7z/7zip`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/7-zip.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/7-zip.deb >/dev/null
7zz i >/dev/null
```

### 2. `act`

- **路径**：`packages/app-utils/act`
- **VER-REL**：`0.2.98-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.2.98::https://github.com/nektos/act`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=nektos/act`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/act.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/act.deb >/dev/null
act --version
```

### 3. `actionlint`

- **路径**：`packages/app-utils/actionlint`
- **VER-REL**：`1.7.12-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v1.7.12::https://github.com/rhysd/actionlint`
- **PKGDEP**：`glibc gcc-runtime`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=rhysd/actionlint`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/actionlint.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/actionlint.deb >/dev/null
actionlint --version
```

### 4. `age`

- **路径**：`packages/app-cryptography/age`
- **VER-REL**：`1.3.2-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/FiloSottile/age`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=FiloSottile/age`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/age.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/age.deb >/dev/null
age --version
```

### 5. `ansible`

- **路径**：`packages/app-utils/ansible`
- **VER-REL**：`2.22.0-1`
- **ABTYPE**：`pep517`
- **source**：`git::commit=tags/v2.22.0::https://github.com/ansible/ansible`
- **PKGDEP**：`python-3 ansible-core`
- **BUILDDEP**：`python-build python-installer`
- **CHKUPDATE**：`anitya::id=6097`
- **构建路线**：Ciel-ACBS：ABHOST=noarch；轻量构建器硬编码 loongarch64，不满足
- **特殊边界**：ABHOST=noarch，产物 Architecture=all
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/ansible.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/ansible.deb >/dev/null
ansible --version
```

### 6. `bandwhich`

- **路径**：`packages/app-network/bandwhich`
- **VER-REL**：`0.23.1-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/imsnif/bandwhich`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=imsnif/bandwhich`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/bandwhich.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/bandwhich.deb >/dev/null
```

### 7. `bashtop`

- **路径**：`packages/app-admin/bashtop`
- **VER-REL**：`0.9.25-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/v$VER::https://github.com/aristocratos/bashtop`
- **PKGDEP**：`bash coreutils procps`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`github::repo=aristocratos/bashtop`
- **构建路线**：Ciel-ACBS：ABHOST=noarch；轻量构建器硬编码 loongarch64，不满足
- **特殊边界**：ABHOST=noarch，产物 Architecture=all
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/bashtop.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/bashtop.deb >/dev/null
```

### 8. `bat-extras`

- **路径**：`packages/app-utils/bat-extras`
- **VER-REL**：`20200408-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/v$VER::https://github.com/eth-p/bat-extras`
- **PKGDEP**：`bat`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **PKGRECOM**：`fzf delta fd ripgrep man`
- **CHKUPDATE**：`github::repo=eth-p/bat-extras`
- **构建路线**：Ciel-ACBS：ABHOST=noarch；轻量构建器硬编码 loongarch64，不满足
- **特殊边界**：ABHOST=noarch，产物 Architecture=all
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/bat-extras.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/bat-extras.deb >/dev/null
```

### 9. `bmake`

- **路径**：`packages/app-devel/bmake`
- **VER-REL**：`20260912-7`
- **ABTYPE**：`self`
- **source**：`tbl::https://www.crufty.net/ftp/pub/sjg/bmake-$VER.tar.gz`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@ python-3`
- **BUILDDEP**：`make gcc`
- **CHKUPDATE**：`none`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **特殊边界**：bmake 由另一 P8 独占，本任务未修改；其 `none` 依据为无 GitHub/Anitya 条目，人工核对 crufty.net 与 NetBSD 日期快照目录。
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/bmake.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/bmake.deb >/dev/null
bmake -V MAKE_VERSION
```

### 10. `brew-ui-linux`

- **路径**：`packages/app-utils/brew-ui-linux`
- **VER-REL**：`0.1.0-5`
- **ABTYPE**：`self`
- **source**：`DUMMYSRC=1`
- **PKGDEP**：`qt-6 glibc gcc-runtime`
- **BUILDDEP**：`gcc-runtime qt-6`
- **CHKUPDATE**：`none`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/brew-ui-linux.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/brew-ui-linux.deb >/dev/null
```

### 11. `broot`

- **路径**：`packages/app-utils/broot`
- **VER-REL**：`1.62.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/Canop/broot`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=Canop/broot`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/broot.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/broot.deb >/dev/null
broot --version
```

### 12. `btrbk`

- **路径**：`packages/app-admin/btrbk`
- **VER-REL**：`0.32.7-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/v$VER::https://github.com/digint/btrbk`
- **PKGDEP**：`perl btrfs-progs`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`github::repo=digint/btrbk`
- **构建路线**：Ciel-ACBS：ABHOST=noarch；轻量构建器硬编码 loongarch64，不满足
- **特殊边界**：ABHOST=noarch，产物 Architecture=all
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/btrbk.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/btrbk.deb >/dev/null
```

### 13. `codespell`

- **路径**：`packages/app-devel/codespell`
- **VER-REL**：`2.4.3-1`
- **ABTYPE**：`pep517`
- **source**：`git::commit=tags/v$VER::https://github.com/codespell-project/codespell`
- **PKGDEP**：`python-3`
- **BUILDDEP**：`python-build python-installer setuptools-scm`
- **CHKUPDATE**：`github::repo=codespell-project/codespell`
- **构建路线**：Ciel-ACBS：ABHOST=noarch；轻量构建器硬编码 loongarch64，不满足
- **特殊边界**：ABHOST=noarch，产物 Architecture=all
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/codespell.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/codespell.deb >/dev/null
```

### 14. `csvlens`

- **路径**：`packages/app-utils/csvlens`
- **VER-REL**：`0.15.1-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/YS-L/csvlens`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=YS-L/csvlens`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/csvlens.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/csvlens.deb >/dev/null
```

### 15. `curlie`

- **路径**：`packages/app-network/curlie`
- **VER-REL**：`1.8.2-3`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/rs/curlie`
- **PKGDEP**：`glibc`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=rs/curlie`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/curlie.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/curlie.deb >/dev/null
curlie --version
```

### 16. `dog`

- **路径**：`packages/app-utils/dog`
- **VER-REL**：`0.1.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v0.1.0::https://github.com/ogham/dog`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=ogham/dog`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/dog.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/dog.deb >/dev/null
dog --version
```

### 17. `dua-cli`

- **路径**：`packages/app-utils/dua-cli`
- **VER-REL**：`3.0.3-2`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/Byron/dua-cli`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=Byron/dua-cli`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/dua-cli.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/dua-cli.deb >/dev/null
```

### 18. `dust`

- **路径**：`packages/app-utils/dust`
- **VER-REL**：`1.2.7-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v1.2.7::https://github.com/bootandy/dust`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=bootandy/dust`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/dust.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/dust.deb >/dev/null
dust --version
```

### 19. `dysk`

- **路径**：`packages/app-utils/dysk`
- **VER-REL**：`3.8.2-2`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/Canop/dysk`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=Canop/dysk`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/dysk.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/dysk.deb >/dev/null
```

### 20. `entr`

- **路径**：`packages/app-utils/entr`
- **VER-REL**：`5.7-1`
- **ABTYPE**：`self`
- **source**：`tbl::https://eradman.com/entrproject/code/entr-${VER}.tar.gz`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`anitya::id=11554`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/entr.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/entr.deb >/dev/null
entr --help 2>&1 | head -n 1
```

### 21. `fclones`

- **路径**：`packages/app-utils/fclones`
- **VER-REL**：`0.35.0-2`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/pkolaczk/fclones`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=pkolaczk/fclones`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/fclones.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/fclones.deb >/dev/null
```

### 22. `fd`

- **路径**：`packages/app-utils/fd`
- **VER-REL**：`10.5.2-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v10.5.2::https://github.com/sharkdp/fd`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=sharkdp/fd`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/fd.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/fd.deb >/dev/null
fd --version
```

### 23. `freeze`

- **路径**：`packages/app-utils/freeze`
- **VER-REL**：`0.2.2-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.2.2::https://github.com/charmbracelet/freeze`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=charmbracelet/freeze`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/freeze.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/freeze.deb >/dev/null
```

### 24. `fx`

- **路径**：`packages/app-utils/fx`
- **VER-REL**：`40.0.1-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/$VER::https://github.com/antonmedv/fx`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=antonmedv/fx`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/fx.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/fx.deb >/dev/null
```

### 25. `fzf`

- **路径**：`packages/app-utils/fzf`
- **VER-REL**：`0.75.0-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.75.0::https://github.com/junegunn/fzf`
- **PKGDEP**：`glibc gcc-runtime`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=junegunn/fzf`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/fzf.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/fzf.deb >/dev/null
fzf --version
```

### 26. `git`

- **路径**：`packages/app-utils/git`
- **VER-REL**：`2.56.1-1`
- **ABTYPE**：`meson`
- **source**：`git::commit=tags/v2.56.1::https://github.com/git/git`
- **PKGDEP**：`curl expat openssl pcre2 perl perl-error cvsps perl-authen-sasl  libwww-perl perl-mime-tools perl-net-smtp-ssl perl-term-readkey  python-3 tk perl-dbi subversion brotli`
- **BUILDDEP**：`xmlto emacs libsecret asciidoc rustc`
- **PKGRECOM**：`git-lfs gitk git-gui`
- **CHKUPDATE**：`anitya::id=5350`
- **构建路线**：Ciel-ACBS：Autobuild4 meson 模板
- **特殊边界**：FAIL_ARCH=!(mainline|retro)
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/git.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/git.deb >/dev/null
git --version
```

### 27. `git-branchless`

- **路径**：`packages/app-utils/git-branchless`
- **VER-REL**：`0.11.1-3`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/arxanas/git-branchless`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=arxanas/git-branchless`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/git-branchless.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/git-branchless.deb >/dev/null
git branchless --version
```

### 28. `git-sizer`

- **路径**：`packages/app-devel/git-sizer`
- **VER-REL**：`1.6.0-3`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/github/git-sizer`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=github/git-sizer`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/git-sizer.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/git-sizer.deb >/dev/null
git-sizer --version
```

### 29. `gitleaks`

- **路径**：`packages/app-devel/gitleaks`
- **VER-REL**：`8.30.1-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/gitleaks/gitleaks`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=gitleaks/gitleaks`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/gitleaks.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/gitleaks.deb >/dev/null
gitleaks version
```

### 30. `gofumpt`

- **路径**：`packages/app-devel/gofumpt`
- **VER-REL**：`0.12.0-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/mvdan/gofumpt`
- **PKGDEP**：`glibc`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=mvdan/gofumpt`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/gofumpt.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/gofumpt.deb >/dev/null
gofumpt --version
```

### 31. `golangci-lint`

- **路径**：`packages/app-devel/golangci-lint`
- **VER-REL**：`2.15.0-3`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/golangci/golangci-lint`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=golangci/golangci-lint`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/golangci-lint.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/golangci-lint.deb >/dev/null
```

### 32. `gpg-tui`

- **路径**：`packages/app-utils/gpg-tui`
- **VER-REL**：`0.11.2-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v0.11.2::https://github.com/orhun/gpg-tui`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=orhun/gpg-tui`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/gpg-tui.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/gpg-tui.deb >/dev/null
```

### 33. `grex`

- **路径**：`packages/app-utils/grex`
- **VER-REL**：`1.4.6-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v1.4.6::https://github.com/pemistahl/grex`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=pemistahl/grex`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/grex.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/grex.deb >/dev/null
```

### 34. `gron`

- **路径**：`packages/app-utils/gron`
- **VER-REL**：`0.7.1-3`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/tomnomnom/gron`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=tomnomnom/gron`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/gron.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/gron.deb >/dev/null
```

### 35. `gum`

- **路径**：`packages/app-utils/gum`
- **VER-REL**：`2.0.2-3`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/charmbracelet/gum`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=charmbracelet/gum`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/gum.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/gum.deb >/dev/null
```

### 36. `helm-docs`

- **路径**：`packages/app-devel/helm-docs`
- **VER-REL**：`1.14.2-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v1.14.2::https://github.com/norwoodj/helm-docs`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=norwoodj/helm-docs`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/helm-docs.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/helm-docs.deb >/dev/null
```

### 37. `hexyl`

- **路径**：`packages/app-utils/hexyl`
- **VER-REL**：`0.17.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/sharkdp/hexyl`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=sharkdp/hexyl`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/hexyl.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/hexyl.deb >/dev/null
```

### 38. `httpie`

- **路径**：`packages/app-utils/httpie`
- **VER-REL**：`3.2.4-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/3.2.4::https://github.com/httpie/cli`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=httpie/cli`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/httpie.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/httpie.deb >/dev/null
http --version
```

### 39. `hurl`

- **路径**：`packages/app-network/hurl`
- **VER-REL**：`8.1.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/$VER::https://github.com/Orange-OpenSource/hurl`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=Orange-OpenSource/hurl`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/hurl.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/hurl.deb >/dev/null
```

### 40. `hwatch`

- **路径**：`packages/app-utils/hwatch`
- **VER-REL**：`0.4.2-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/0.4.2::https://github.com/blacknon/hwatch`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=blacknon/hwatch`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/hwatch.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/hwatch.deb >/dev/null
```

### 41. `hyperfine`

- **路径**：`packages/app-utils/hyperfine`
- **VER-REL**：`2.0.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v2.0.0::https://github.com/sharkdp/hyperfine`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=sharkdp/hyperfine`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/hyperfine.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/hyperfine.deb >/dev/null
hyperfine --version
```

### 42. `igrep`

- **路径**：`packages/app-utils/igrep`
- **VER-REL**：`1.3.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/konradsz/igrep`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=konradsz/igrep`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/igrep.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/igrep.deb >/dev/null
```

### 43. `jaq`

- **路径**：`packages/app-utils/jaq`
- **VER-REL**：`3.1.2-2`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/01mf02/jaq`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=01mf02/jaq`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/jaq.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/jaq.deb >/dev/null
```

### 44. `jira-cli`

- **路径**：`packages/app-utils/jira-cli`
- **VER-REL**：`1.7.0-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v1.7.0::https://github.com/ankitpokhrel/jira-cli`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=ankitpokhrel/jira-cli`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/jira-cli.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/jira-cli.deb >/dev/null
```

### 45. `jless`

- **路径**：`packages/app-utils/jless`
- **VER-REL**：`0.9.0-2`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/PaulJuliusMartinez/jless`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm libxcb`
- **CHKUPDATE**：`github::repo=PaulJuliusMartinez/jless`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/jless.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/jless.deb >/dev/null
```

### 46. `jnv`

- **路径**：`packages/app-utils/jnv`
- **VER-REL**：`0.7.1-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v0.7.1::https://github.com/ynqa/jnv`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=ynqa/jnv`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/jnv.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/jnv.deb >/dev/null
```

### 47. `just`

- **路径**：`packages/app-utils/just`
- **VER-REL**：`1.59.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/$VER::https://github.com/casey/just`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=casey/just`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/just.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/just.deb >/dev/null
just --version
```

### 48. `k9s`

- **路径**：`packages/app-utils/k9s`
- **VER-REL**：`0.51.0-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.51.0::https://github.com/derailed/k9s`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=derailed/k9s`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/k9s.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/k9s.deb >/dev/null
```

### 49. `kube-capacity`

- **路径**：`packages/app-utils/kube-capacity`
- **VER-REL**：`0.8.0-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.8.0::https://github.com/robscott/kube-capacity`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=robscott/kube-capacity`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/kube-capacity.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/kube-capacity.deb >/dev/null
```

### 50. `kube-score`

- **路径**：`packages/app-utils/kube-score`
- **VER-REL**：`1.20.0-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v1.20.0::https://github.com/zegl/kube-score`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=zegl/kube-score`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/kube-score.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/kube-score.deb >/dev/null
```

### 51. `kubecolor`

- **路径**：`packages/app-utils/kubecolor`
- **VER-REL**：`0.0.25-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.0.25::https://github.com/hidetatz/kubecolor`
- **PKGDEP**：`glibc gcc-runtime`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=hidetatz/kubecolor`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/kubecolor.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/kubecolor.deb >/dev/null
```

### 52. `kubeconform`

- **路径**：`packages/app-utils/kubeconform`
- **VER-REL**：`0.8.0-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.8.0::https://github.com/yannh/kubeconform`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=yannh/kubeconform`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/kubeconform.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/kubeconform.deb >/dev/null
```

### 53. `kubectl-ai`

- **路径**：`packages/app-utils/kubectl-ai`
- **VER-REL**：`0.0.31-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.0.31::https://github.com/GoogleCloudPlatform/kubectl-ai`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=GoogleCloudPlatform/kubectl-ai`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/kubectl-ai.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/kubectl-ai.deb >/dev/null
kubectl-ai --version
```

### 54. `kubectl-neat`

- **路径**：`packages/app-utils/kubectl-neat`
- **VER-REL**：`2.0.4-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v2.0.4::https://github.com/itaysk/kubectl-neat`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=itaysk/kubectl-neat`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/kubectl-neat.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/kubectl-neat.deb >/dev/null
```

### 55. `kubectl-tree`

- **路径**：`packages/app-utils/kubectl-tree`
- **VER-REL**：`0.6.0-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.6.0::https://github.com/ahmetb/kubectl-tree`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=ahmetb/kubectl-tree`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/kubectl-tree.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/kubectl-tree.deb >/dev/null
```

### 56. `kubeswitch`

- **路径**：`packages/app-utils/kubeswitch`
- **VER-REL**：`0.9.3-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/0.9.3::https://github.com/danielfoehrKn/kubeswitch`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=danielfoehrKn/kubeswitch`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/kubeswitch.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/kubeswitch.deb >/dev/null
```

### 57. `kustomize`

- **路径**：`packages/app-admin/kustomize`
- **VER-REL**：`5.8.3-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/kustomize/v$VER::https://github.com/kubernetes-sigs/kustomize`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=kubernetes-sigs/kustomize`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/kustomize.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/kustomize.deb >/dev/null
```

### 58. `lazydocker`

- **路径**：`packages/app-utils/lazydocker`
- **VER-REL**：`0.25.2-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.25.2::https://github.com/jesseduffield/lazydocker`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=jesseduffield/lazydocker`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/lazydocker.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/lazydocker.deb >/dev/null
```

### 59. `lazysql`

- **路径**：`packages/app-utils/lazysql`
- **VER-REL**：`0.7.0-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.7.0::https://github.com/jorgerojas26/lazysql`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=jorgerojas26/lazysql`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/lazysql.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/lazysql.deb >/dev/null
```

### 60. `lf`

- **路径**：`packages/app-utils/lf`
- **VER-REL**：`42-3`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/r$VER::https://github.com/gokcehan/lf`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=gokcehan/lf`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/lf.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/lf.deb >/dev/null
lf -version
```

### 61. `lhasa`

- **路径**：`packages/app-utils/lhasa`
- **VER-REL**：`0.6.0-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/v$VER::https://github.com/fragglet/lhasa`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`github::repo=fragglet/lhasa`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/lhasa.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/lhasa.deb >/dev/null
```

### 62. `libmspack`

- **路径**：`packages/app-libs/libmspack`
- **VER-REL**：`1.12-2`
- **ABTYPE**：`self`
- **source**：`tbl::https://github.com/kyz/libmspack/archive/refs/tags/v$VER.tar.gz`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`autoconf automake libtool m4`
- **CHKUPDATE**：`github::repo=kyz/libmspack`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/libmspack.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/libmspack.deb >/dev/null
```

### 63. `libpng`

- **路径**：`packages/runtime-imaging/libpng`
- **VER-REL**：`1.6.59-4`
- **ABTYPE**：`autotools`
- **source**：`git::commit=tags/v$VER::https://github.com/pnggroup/libpng`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`anitya::id=1705`
- **构建路线**：Ciel-ACBS：Autobuild4 autotools 模板
- **特殊边界**：FAIL_ARCH=!(mainline|retro)
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/libpng.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/libpng.deb >/dev/null
dpkg-query -W -f="${Status} ${Version}\n" libpng
```

### 64. `linux-kernel-mainline-16k-rt`

- **路径**：`packages/kernel/linux-kernel-mainline-16k-rt`
- **VER-REL**：`7.3.4-2`
- **ABTYPE**：`self`
- **source**：`tarball::https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-${VER}.tar.xz`
- **PKGDEP**：`kmod dracut-ng`
- **BUILDDEP**：`gcc clang lld llvm bc bison flex pahole perl rsync`
- **CHKUPDATE**：`kernel::stable`
- **构建路线**：专用内核双变体流程（Ciel/独立内核脚本）；禁止轻量 self 通用路线
- **特殊边界**：专用 gcc-o3/clang-lto 双变体流程，不走轻量构建器。必须在 LoongArch64 实机启动后验证 16K 页、PREEMPT_RT、DKMS 与匹配 headers；虚拟机元数据检查不能替代启动验收。
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/linux-kernel-mainline-16k-rt.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/linux-kernel-mainline-16k-rt.deb >/dev/null
getconf PAGE_SIZE
cat /sys/kernel/realtime
uname -r
dkms status
```

### 65. `linuxsampler`

- **路径**：`packages/runtime-multimedia/linuxsampler`
- **VER-REL**：`2.4.2-1`
- **ABTYPE**：`autotools`
- **source**：`tbl::https://download.linuxsampler.org/packages/linuxsampler-$VER.tar.bz2`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`dssi bison flex ladspa-sdk`
- **CHKUPDATE**：`github::repo=linuxsampler/linuxsampler`
- **构建路线**：Ciel-ACBS：Autobuild4 autotools 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/linuxsampler.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/linuxsampler.deb >/dev/null
```

### 66. `loonggpu-kernel-dkms`

- **路径**：`packages/graphics-drivers/loonggpu-dkms`
- **VER-REL**：`2:1.0.2+lnd25.1-3`
- **ABTYPE**：`(Autobuild 默认)`
- **source**：`file::use-url-name=true::https://repo.aosc.io/aosc-repacks/loonggpu/loonggpu-kernel-dkms_${UPSTREAM_VER}_loong64.deb`
- **PKGDEP**：`dracut dkms firmware-loongson-graphics`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`none`
- **构建路线**：Ciel-ACBS：必须保留 EPOCH；轻量构建器不满足
- **特殊边界**：EPOCH=2 FAIL_ARCH=!(loongarch64) 带 EPOCH=2，轻量构建器会丢 EPOCH，禁止用其产物发布。需与正在运行的 16K 内核/headers 和 LoongGPU 固件匹配，实机验证 DKMS 模块加载。
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/loonggpu-kernel-dkms.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/loonggpu-kernel-dkms.deb >/dev/null
dkms status | grep loonggpu
```

### 67. `loongvpu-open`

- **路径**：`packages/graphics-drivers/loongvpu-open`
- **VER-REL**：`0.0.0+git20261118.8d952056-6`
- **ABTYPE**：`self`
- **source**：`git::commit=8d95205627f83f6b36d09a9263ac9f381959c6c3::https://github.com/tsuibin/loongvpu-vaapi-loongarch64`
- **PKGDEP**：`glibc loonggpu-driver(>=2:1.0.2+lnd25.1) loongvpu-kernel-dkms(>=1.0.1+lnd25.1~pre20260926T123109Z) libva(>=2.23.0)`
- **BUILDDEP**：`gcc git make libva-dev libdrm-dev pkg-config`
- **CHKUPDATE**：`none`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **特殊边界**：FAIL_ARCH=!(loongarch64) 实验性 LG200 边界，defines 明确 UNTESTED_ON_LG200 且不支持 LS9A；vainfo 只能在对应 VPU/内核驱动/固件齐备的实机执行，不宣称已验证。
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/loongvpu-open.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/loongvpu-open.deb >/dev/null
vainfo
```

### 68. `mesa-vulkan-loonggpu`

- **路径**：`packages/graphics-drivers/mesa-vulkan-loonggpu`
- **VER-REL**：`26.1.5-1`
- **ABTYPE**：`self`
- **source**：`tarball::https://archive.mesa3d.org/mesa-${VER}.tar.gz`
- **PKGDEP**：`mesa libdrm`
- **BUILDDEP**：`meson ninja gcc python-3 llvm`
- **CHKUPDATE**：`none`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **特殊边界**：已废弃的实验 RADV 存档，不代表 LG110 可用原生 Vulkan；仅保留复现路线，不能与 vkgl 的能力混同。
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/mesa-vulkan-loonggpu.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/mesa-vulkan-loonggpu.deb >/dev/null
```

### 69. `miniupnpc`

- **路径**：`packages/net/miniupnpc`
- **VER-REL**：`2.2.8-2`
- **ABTYPE**：`self`
- **source**：`https://miniupnp.tuxfamily.org/files/miniupnpc-${VER}.tar.gz`
- **PKGDEP**：`glibc gcc-runtime`
- **BUILDDEP**：`gcc make`
- **CHKUPDATE**：`none`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/miniupnpc.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/miniupnpc.deb >/dev/null
```

### 70. `mise`

- **路径**：`packages/app-utils/mise`
- **VER-REL**：`2026.11.9-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v2026.11.9::https://github.com/jdx/mise`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=jdx/mise`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/mise.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/mise.deb >/dev/null
mise --version
```

### 71. `mkcert`

- **路径**：`packages/app-cryptography/mkcert`
- **VER-REL**：`1.4.4-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/FiloSottile/mkcert`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=FiloSottile/mkcert`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/mkcert.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/mkcert.deb >/dev/null
```

### 72. `moar`

- **路径**：`packages/app-utils/moar`
- **VER-REL**：`2.19.7-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/walles/moar`
- **PKGDEP**：`glibc`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=walles/moar`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/moar.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/moar.deb >/dev/null
```

### 73. `muffet`

- **路径**：`packages/app-utils/muffet`
- **VER-REL**：`2.11.8-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v2.11.8::https://github.com/raviqqe/muffet`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=raviqqe/muffet`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/muffet.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/muffet.deb >/dev/null
```

### 74. `navi`

- **路径**：`packages/app-utils/navi`
- **VER-REL**：`2.24.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v2.24.0::https://github.com/denisidoro/navi`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=denisidoro/navi`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/navi.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/navi.deb >/dev/null
```

### 75. `nu`

- **路径**：`packages/app-shells/nu`
- **VER-REL**：`0.117.0-2`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/0.117.0::https://github.com/nushell/nushell`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=nushell/nushell`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/nu.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/nu.deb >/dev/null
nu --version
```

### 76. `oha`

- **路径**：`packages/app-network/oha`
- **VER-REL**：`1.17.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v1.17.0::https://github.com/hatoo/oha`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=hatoo/oha`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/oha.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/oha.deb >/dev/null
```

### 77. `ov`

- **路径**：`packages/app-utils/ov`
- **VER-REL**：`0.55.0-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/noborus/ov`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=noborus/ov`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/ov.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/ov.deb >/dev/null
```

### 78. `plasma-loonggpu-compat`

- **路径**：`packages/desktop-plasma/plasma-loonggpu-compat`
- **VER-REL**：`1.0.4-1`
- **ABTYPE**：`self`
- **source**：`dir::files`
- **PKGDEP**：`kwin plasma-workspace wayland libdrm`
- **BUILDDEP**：`gcc gcc-runtime qt-6 pkgconf`
- **CHKUPDATE**：`none`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **特殊边界**：KWin 私有 ABI/LoongGPU Wayland 边界；重建需 KWIN_SOURCE_DIR/KWIN_BUILD_DIR 或已验证桥二进制，最终需 LG110 Plasma/Wayland 会话验证。
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/plasma-loonggpu-compat.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/plasma-loonggpu-compat.deb >/dev/null
```

### 79. `pop`

- **路径**：`packages/app-utils/pop`
- **VER-REL**：`0.5.0-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.5.0::https://github.com/charmbracelet/pop`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=charmbracelet/pop`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/pop.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/pop.deb >/dev/null
```

### 80. `popeye`

- **路径**：`packages/app-utils/popeye`
- **VER-REL**：`0.22.1-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v0.22.1::https://github.com/derailed/popeye`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=derailed/popeye`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/popeye.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/popeye.deb >/dev/null
```

### 81. `prettyping`

- **路径**：`packages/app-network/prettyping`
- **VER-REL**：`1.1.0-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/v$VER::https://github.com/denilsonsa/prettyping`
- **PKGDEP**：`iputils`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`github::repo=denilsonsa/prettyping`
- **构建路线**：Ciel-ACBS：ABHOST=noarch；轻量构建器硬编码 loongarch64，不满足
- **特殊边界**：ABHOST=noarch，产物 Architecture=all
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/prettyping.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/prettyping.deb >/dev/null
```

### 82. `procs`

- **路径**：`packages/app-admin/procs`
- **VER-REL**：`0.14.12-2`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/dalance/procs`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=dalance/procs`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/procs.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/procs.deb >/dev/null
```

### 83. `pueue`

- **路径**：`packages/app-utils/pueue`
- **VER-REL**：`4.0.4-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v4.0.4::https://github.com/Nukesor/pueue`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=Nukesor/pueue`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/pueue.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/pueue.deb >/dev/null
```

### 84. `pyenv`

- **路径**：`packages/app-devel/pyenv`
- **VER-REL**：`2.8.15-2`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/v$VER::https://github.com/pyenv/pyenv`
- **PKGDEP**：`glibc bash curl git`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`github::repo=pyenv/pyenv`
- **构建路线**：Ciel-ACBS：ABHOST=noarch；轻量构建器硬编码 loongarch64，不满足
- **特殊边界**：ABHOST=noarch，产物 Architecture=all
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/pyenv.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/pyenv.deb >/dev/null
```

### 85. `ripgrep`

- **路径**：`packages/app-utils/ripgrep`
- **VER-REL**：`15.2.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/15.2.0::https://github.com/BurntSushi/ripgrep`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=BurntSushi/ripgrep`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/ripgrep.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/ripgrep.deb >/dev/null
rg --version
```

### 86. `ripgrep-all`

- **路径**：`packages/app-utils/ripgrep-all`
- **VER-REL**：`0.10.10-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v0.10.10::https://github.com/phiresky/ripgrep-all`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=phiresky/ripgrep-all`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/ripgrep-all.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/ripgrep-all.deb >/dev/null
```

### 87. `ruby`

- **路径**：`packages/runtime-ruby/ruby`
- **VER-REL**：`4.0.9-2`
- **ABTYPE**：`self`
- **source**：`file::https://cache.ruby-lang.org/pub/ruby/${VER%.*}/ruby-${VER}.tar.gz`
- **PKGDEP**：`gcc-runtime glibc gdbm openssl libffi yaml gmp zlib ncurses readline`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`ruby`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/ruby.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/ruby.deb >/dev/null
ruby --version
```

### 88. `sad`

- **路径**：`packages/app-utils/sad`
- **VER-REL**：`0.4.33-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/ms-jpq/sad`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=ms-jpq/sad`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/sad.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/sad.deb >/dev/null
```

### 89. `samurai`

- **路径**：`packages/app-devel/samurai`
- **VER-REL**：`1.3-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/1.3::https://github.com/michaelforney/samurai`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`gcc make`
- **CHKUPDATE**：`github::repo=michaelforney/samurai`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/samurai.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/samurai.deb >/dev/null
```

### 90. `sccache`

- **路径**：`packages/app-utils/sccache`
- **VER-REL**：`0.19.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v0.19.0::https://github.com/mozilla/sccache`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=mozilla/sccache`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/sccache.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/sccache.deb >/dev/null
sccache --version
```

### 91. `sd`

- **路径**：`packages/app-utils/sd`
- **VER-REL**：`1.1.0-5`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/chmln/sd`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=chmln/sd`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/sd.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/sd.deb >/dev/null
```

### 92. `shellharden`

- **路径**：`packages/app-utils/shellharden`
- **VER-REL**：`4.3.2-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v4.3.2::https://github.com/anordal/shellharden`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=anordal/shellharden`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/shellharden.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/shellharden.deb >/dev/null
```

### 93. `skim`

- **路径**：`packages/app-utils/skim`
- **VER-REL**：`5.9.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/lotabout/skim`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=lotabout/skim`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/skim.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/skim.deb >/dev/null
```

### 94. `sops`

- **路径**：`packages/app-cryptography/sops`
- **VER-REL**：`3.13.3-3`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/getsops/sops`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=getsops/sops`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/sops.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/sops.deb >/dev/null
```

### 95. `speedtest-cli`

- **路径**：`packages/app-network/speedtest-cli`
- **VER-REL**：`2.1.3-1`
- **ABTYPE**：`pep517`
- **source**：`git::commit=tags/v$VER::https://github.com/sivel/speedtest-cli`
- **PKGDEP**：`python-3`
- **BUILDDEP**：`python-build python-installer`
- **CHKUPDATE**：`github::repo=sivel/speedtest-cli`
- **构建路线**：Ciel-ACBS：ABHOST=noarch；轻量构建器硬编码 loongarch64，不满足
- **特殊边界**：ABHOST=noarch，产物 Architecture=all
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/speedtest-cli.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/speedtest-cli.deb >/dev/null
```

### 96. `spirv-cross`

- **路径**：`packages/app-devel/spirv-cross`
- **VER-REL**：`1.4.363.0-6`
- **ABTYPE**：`cmakeninja`
- **source**：`git::commit=tags/vulkan-sdk-$VER::https://github.com/KhronosGroup/SPIRV-Cross`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`cmake ninja python-3`
- **CHKUPDATE**：`github::repo=KhronosGroup/SPIRV-Cross`
- **构建路线**：Ciel-ACBS：Autobuild4 cmakeninja 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/spirv-cross.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/spirv-cross.deb >/dev/null
```

### 97. `staticcheck`

- **路径**：`packages/app-devel/staticcheck`
- **VER-REL**：`2026.2.2-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/$VER::https://github.com/dominikh/go-tools`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=dominikh/go-tools`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/staticcheck.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/staticcheck.deb >/dev/null
```

### 98. `stern`

- **路径**：`packages/app-utils/stern`
- **VER-REL**：`1.35.0-1`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v1.35.0::https://github.com/stern/stern`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=stern/stern`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/stern.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/stern.deb >/dev/null
```

### 99. `superfile`

- **路径**：`packages/app-utils/superfile`
- **VER-REL**：`1.6.0-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/yorukot/superfile`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=yorukot/superfile`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/superfile.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/superfile.deb >/dev/null
```

### 100. `taplo`

- **路径**：`packages/app-devel/taplo`
- **VER-REL**：`0.10.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/0.10.0::https://github.com/tamasfe/taplo`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=tamasfe/taplo`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/taplo.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/taplo.deb >/dev/null
```

### 101. `tdf`

- **路径**：`packages/app-utils/tdf`
- **VER-REL**：`0.5.0-3`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/itsjunetime/tdf`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=itsjunetime/tdf`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/tdf.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/tdf.deb >/dev/null
```

### 102. `tealdeer`

- **路径**：`packages/app-utils/tealdeer`
- **VER-REL**：`1.9.1-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v1.9.1::https://github.com/dbrgn/tealdeer`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=dbrgn/tealdeer`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/tealdeer.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/tealdeer.deb >/dev/null
tldr --version
```

### 103. `tectonic`

- **路径**：`packages/app-doc/tectonic`
- **VER-REL**：`0.17.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/tectonic@$VER::https://github.com/tectonic-typesetting/tectonic`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=tectonic-typesetting/tectonic`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/tectonic.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/tectonic.deb >/dev/null
```

### 104. `trippy`

- **路径**：`packages/app-network/trippy`
- **VER-REL**：`0.13.0-2`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/$VER::https://github.com/fujiapple852/trippy`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=fujiapple852/trippy`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/trippy.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/trippy.deb >/dev/null
```

### 105. `trivy`

- **路径**：`packages/app-devel/trivy`
- **VER-REL**：`0.76.2-2`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/aquasecurity/trivy`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=aquasecurity/trivy`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/trivy.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/trivy.deb >/dev/null
```

### 106. `v2raya`

- **路径**：`packages/app-proxy/v2raya`
- **VER-REL**：`2.5.15-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/v$VER::https://github.com/v2rayA/v2rayA`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go nodejs yarn`
- **CHKUPDATE**：`github::repo=v2rayA/v2rayA`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/v2raya.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/v2raya.deb >/dev/null
```

### 107. `valkey`

- **路径**：`packages/app-database/valkey`
- **VER-REL**：`9.1.3-2`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/$VER::https://github.com/valkey-io/valkey`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`github::repo=valkey-io/valkey`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/valkey.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/valkey.deb >/dev/null
valkey-server --version
```

### 108. `vegeta`

- **路径**：`packages/app-network/vegeta`
- **VER-REL**：`12.13.0-4`
- **ABTYPE**：`gomod`
- **source**：`git::commit=tags/v$VER::https://github.com/tsenart/vegeta`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`go`
- **CHKUPDATE**：`github::repo=tsenart/vegeta`
- **构建路线**：Ciel-ACBS：Autobuild4 gomod 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/vegeta.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/vegeta.deb >/dev/null
```

### 109. `visidata`

- **路径**：`packages/app-utils/visidata`
- **VER-REL**：`3.5-1`
- **ABTYPE**：`pep517`
- **source**：`git::commit=tags/v$VER::https://github.com/saulpw/visidata`
- **PKGDEP**：`python-3 dateutil requests pyyaml`
- **BUILDDEP**：`python-build python-installer`
- **CHKUPDATE**：`github::repo=saulpw/visidata`
- **构建路线**：Ciel-ACBS：ABHOST=noarch；轻量构建器硬编码 loongarch64，不满足
- **特殊边界**：ABHOST=noarch，产物 Architecture=all
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/visidata.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/visidata.deb >/dev/null
```

### 110. `vivid`

- **路径**：`packages/app-utils/vivid`
- **VER-REL**：`0.11.1-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v0.11.1::https://github.com/sharkdp/vivid`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=sharkdp/vivid`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/vivid.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/vivid.deb >/dev/null
vivid --version
```

### 111. `vkgl-loonggpu`

- **路径**：`packages/graphics-drivers/vkgl-loonggpu`
- **VER-REL**：`0.1.36-1`
- **ABTYPE**：`self`
- **source**：`dir::files`
- **PKGDEP**：`loonggl mesa wayland libdrm`
- **BUILDDEP**：`gcc gcc-runtime spirv-cross`
- **CHKUPDATE**：`none`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **特殊边界**：LG110 + 匹配 loonggpu/loonggl 栈的硬件边界；通用 CPU/无关 GPU 的 vulkaninfo 不算验收。
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/vkgl-loonggpu.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/vkgl-loonggpu.deb >/dev/null
vulkaninfo --summary
```

### 112. `vkmark`

- **路径**：`packages/graphics-drivers/vkmark`
- **VER-REL**：`2025.01-4`
- **ABTYPE**：`self`
- **source**：`tbl::https://github.com/vkmark/vkmark/archive/83a128d65b1adddfacb4fa2e555a7e90817a7266.tar.gz`
- **PKGDEP**：`vulkan-loader libxcb xcb-util-wm wayland mesa libdrm assimp`
- **BUILDDEP**：`meson ninja vulkan-headers glm wayland libxcb xcb-util-wm libdrm assimp`
- **CHKUPDATE**：`github::repo=vkmark/vkmark`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **特殊边界**：GPU 基准程序；在 LoongGPU 路线下须明确实际 Vulkan ICD 与显示会话，不能用 llvmpipe 结果冒充硬件验收。
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/vkmark.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/vkmark.deb >/dev/null
vkmark --help
```

### 113. `watchexec`

- **路径**：`packages/app-devel/watchexec`
- **VER-REL**：`2.8.0-2`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/watchexec/watchexec`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=watchexec/watchexec`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/watchexec.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/watchexec.deb >/dev/null
```

### 114. `wowtype`

- **路径**：`packages/i18n/wowtype`
- **VER-REL**：`0.7.3-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/v$VER::https://github.com/Gloridust/WowType`
- **PKGDEP**：`glibc gcc-runtime fcitx5 python-3 pygobject-3 gtk-4 libadwaita`
- **BUILDDEP**：`cargo extra-cmake-modules`
- **CHKUPDATE**：`github::repo=Gloridust/WowType`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **特殊边界**：构建内含 cargo test、词典和 dlopen 闸；完整输入法验收还需 Fcitx 5 桌面会话。
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/wowtype.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/wowtype.deb >/dev/null
W=/usr/share/wowtype; wowtype-check --lexicon "$W/lexicon.tsv" --lm "$W/words.lm" --s2t "$W/s2t.tsv"
```

### 115. `wrk`

- **路径**：`packages/app-network/wrk`
- **VER-REL**：`4.2.0-1`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/$VER::https://github.com/wg/wrk`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`(无显式声明；BuildKit 基础工具仍可用)`
- **CHKUPDATE**：`github::repo=wg/wrk`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/wrk.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/wrk.deb >/dev/null
```

### 116. `xcp`

- **路径**：`packages/app-utils/xcp`
- **VER-REL**：`0.24.2-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v0.24.2::https://github.com/tarka/xcp`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=tarka/xcp`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/xcp.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/xcp.deb >/dev/null
```

### 117. `xh`

- **路径**：`packages/app-network/xh`
- **VER-REL**：`0.26.3-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v$VER::https://github.com/ducaale/xh`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm openssl`
- **CHKUPDATE**：`github::repo=ducaale/xh`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/xh.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/xh.deb >/dev/null
```

### 118. `xsv`

- **路径**：`packages/app-utils/xsv`
- **VER-REL**：`0.13.0-4`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/$VER::https://github.com/BurntSushi/xsv`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=BurntSushi/xsv`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/xsv.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/xsv.deb >/dev/null
```

### 119. `yamllint`

- **路径**：`packages/app-devel/yamllint`
- **VER-REL**：`1.38.0-2`
- **ABTYPE**：`pep517`
- **source**：`git::commit=tags/v$VER::https://github.com/adrienverge/yamllint`
- **PKGDEP**：`python-3 pathspec pyyaml`
- **BUILDDEP**：`python-build python-installer`
- **CHKUPDATE**：`github::repo=adrienverge/yamllint`
- **构建路线**：Ciel-ACBS：ABHOST=noarch；轻量构建器硬编码 loongarch64，不满足
- **特殊边界**：ABHOST=noarch，产物 Architecture=all
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/yamllint.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/yamllint.deb >/dev/null
```

### 120. `zerotier-one`

- **路径**：`packages/app-network/zerotier-one`
- **VER-REL**：`1.16.2-3`
- **ABTYPE**：`self`
- **source**：`git::commit=tags/1.16.2::https://github.com/zerotier/ZeroTierOne`
- **PKGDEP**：`glibc gcc-runtime miniupnpc`
- **BUILDDEP**：`git miniupnpc`
- **CHKUPDATE**：`github::repo=zerotier/ZeroTierOne`
- **构建路线**：轻量 self 可用：scripts/build-package.sh；权威复现仍建议 Ciel-ACBS
- **特殊边界**：服务/网络验收须隔离环境，不能为 smoke 修改生产 ZeroTier 网络配置。
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/zerotier-one.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/zerotier-one.deb >/dev/null
zerotier-cli info
```

### 121. `zizmor`

- **路径**：`packages/app-devel/zizmor`
- **VER-REL**：`1.32.0-1`
- **ABTYPE**：`rust`
- **source**：`git::commit=tags/v1.32.0::https://github.com/zizmorcore/zizmor`
- **PKGDEP**：`@AB_AUTO_SO_DEPS@`
- **BUILDDEP**：`rustc llvm`
- **CHKUPDATE**：`github::repo=zizmorcore/zizmor`
- **构建路线**：Ciel-ACBS：Autobuild4 rust 模板
- **可执行验证命令（计划，未执行）**：

```bash
dpkg-deb -f /path/to/zizmor.deb Package Version Architecture Depends
dpkg-deb --contents /path/to/zizmor.deb >/dev/null
zizmor --version
```
