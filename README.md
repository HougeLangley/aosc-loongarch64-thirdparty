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
sudo apt install wowtype           # 微信风格拼音输入法（fcitx5；AOSC 文本版，无语音组件）
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
当前列出 **97 个最新 deb 条目、97 个不同包名**；索引共保留 98 个 deb（含历史版本），每个包只列最新版本。
旧版本只保留有限的回滚副本，不在 README 罗列。APT 默认选择可安装的最新版本。
`mesa-vulkan-loonggpu` 仍只是已废弃的 RADV 存档，不代表 LG110 可用原生 Vulkan。

| 软件包 | 版本 | 架构 | SHA-256 | deb |
|---|---|---|---|---|
| `age` | `1.3.2-2` | `loongarch64` | `455107df3c65388858df62fdbf38e899c688b1fd1919a1b6a8f028037f1a1648` | [下载](https://homebrewloongarch64.site/aosc/pool/main/a/age/age_1.3.2-2_loongarch64.deb) |
| `bandwhich` | `0.23.1-1` | `loongarch64` | `9651fab2fffcdbb9c444c8fed8f87a36b323eb0b3e507edccdcdfb30ceef0fb6` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/bandwhich/bandwhich_0.23.1-1_loongarch64.deb) |
| `bashtop` | `0.9.25-1` | `all` | `860196f1129d3b620332f3ff799df888b22488271ca9bbfca66e506509a5ebbf` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/bashtop/bashtop_0.9.25-1_all.deb) |
| `bat-extras` | `20200408-1` | `all` | `fed73be637a3e53173ebfc40e97b3ac561a1de92b0f21836b3ddc2be31d1649f` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/bat-extras/bat-extras_20200408-1_all.deb) |
| `bmake` | `20260912-3` | `loongarch64` | `b7d6fc3d23060b31b95799db9d850b851aa4f39811a5803d2ef75ea3bf738464` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/bmake/bmake_20260912-3_loongarch64.deb) |
| `brew-ui-linux` | `0.1.0-5` | `loongarch64` | `f31a56110f420390f32cb2f795b8984109f41187382cbd4cc7e374184c30f481` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/brew-ui-linux/brew-ui-linux_0.1.0-5_loongarch64.deb) |
| `broot` | `1.62.0-1` | `loongarch64` | `3ffc26da70fc9fe18363d8bdd3958a0d47cf1a5f255d8804ade947b675d78610` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/broot/broot_1.62.0-1_loongarch64.deb) |
| `btrbk` | `0.32.7-1` | `all` | `88a34fc209ddd520c1ef1d52d2ec9a07734ac1d07c0ca9c87d872abe1d21c9ae` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/btrbk/btrbk_0.32.7-1_all.deb) |
| `codespell` | `2.4.3-1` | `all` | `8e2ead6b2393978704d4b4744da2507182542031eb87bb4cc1fbc34f9b3b6ec7` | [下载](https://homebrewloongarch64.site/aosc/pool/main/c/codespell/codespell_2.4.3-1_all.deb) |
| `csvlens` | `0.15.1-1` | `loongarch64` | `8a52b7190e37a2bfe6fd7ed32de4f8f1f44a248e0a62ac0648ec96f8ea3e42e0` | [下载](https://homebrewloongarch64.site/aosc/pool/main/c/csvlens/csvlens_0.15.1-1_loongarch64.deb) |
| `curlie` | `1.8.2-3` | `loongarch64` | `cca1d461744b6cdf5ee9c363eee69a325a7210da3cf62046512595784045daf9` | [下载](https://homebrewloongarch64.site/aosc/pool/main/c/curlie/curlie_1.8.2-3_loongarch64.deb) |
| `dua-cli` | `3.0.3-2` | `loongarch64` | `a4a4a37c1cad0f4a892cde4fc54b8aed84d541e370c079bbb3d8d22e57d76332` | [下载](https://homebrewloongarch64.site/aosc/pool/main/d/dua-cli/dua-cli_3.0.3-2_loongarch64.deb) |
| `dysk` | `3.8.2-2` | `loongarch64` | `6006480447e3a5b7a5df946f32658fa0318733e22f80bd9f14e8ea90bf6ca54a` | [下载](https://homebrewloongarch64.site/aosc/pool/main/d/dysk/dysk_3.8.2-2_loongarch64.deb) |
| `entr` | `5.7-1` | `loongarch64` | `4252ecc9c497e8badb3c2871f65ed2fcf8836632d06db0c5c0971e7e6d95dfc6` | [下载](https://homebrewloongarch64.site/aosc/pool/main/e/entr/entr_5.7-1_loongarch64.deb) |
| `fclones` | `0.35.0-2` | `loongarch64` | `0a97e1075cc3fa5d9bb05a217f8f8c6f37d0bd9319cbdc3e33237bc8bef5cf2c` | [下载](https://homebrewloongarch64.site/aosc/pool/main/f/fclones/fclones_0.35.0-2_loongarch64.deb) |
| `freeze` | `0.2.2-1` | `loongarch64` | `56f65c6230f49b07adcdc6fd2d0bfd9957b42191c461b3d1318b472304e68f3f` | [下载](https://homebrewloongarch64.site/aosc/pool/main/f/freeze/freeze_0.2.2-1_loongarch64.deb) |
| `fx` | `40.0.1-1` | `loongarch64` | `49c148a573c18723a3644a12b953b1d733bf5925898594084571d154ded84d40` | [下载](https://homebrewloongarch64.site/aosc/pool/main/f/fx/fx_40.0.1-1_loongarch64.deb) |
| `git-branchless` | `0.11.1-3` | `loongarch64` | `2cb0e8b108f64259cb1369108fa84a449ddffa1338473b891981972c2bcd9886` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/git-branchless/git-branchless_0.11.1-3_loongarch64.deb) |
| `git-sizer` | `1.6.0-3` | `loongarch64` | `5cebd6d3a89d675461d79b52be0037accf9e753b339838910326c304ddcbc495` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/git-sizer/git-sizer_1.6.0-3_loongarch64.deb) |
| `gitleaks` | `8.30.1-2` | `loongarch64` | `df526aaf4e9a3bcf1df31a01eb735f84d7297f0925a21aeaaecf242b4f7946ae` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/gitleaks/gitleaks_8.30.1-2_loongarch64.deb) |
| `gofumpt` | `0.12.0-2` | `loongarch64` | `09be53f99609d82c94ff1b1a1c8e71557888a5cf37ef9b30ba6048181087b929` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/gofumpt/gofumpt_0.12.0-2_loongarch64.deb) |
| `golangci-lint` | `2.15.0-3` | `loongarch64` | `e61eeca13ba2904037c8c467cc7431c7a32f4f6e7d5ef50ba95c3908ef730497` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/golangci-lint/golangci-lint_2.15.0-3_loongarch64.deb) |
| `gpg-tui` | `0.11.2-1` | `loongarch64` | `9d5082e514014d0e854964b2edb12ac0a5e1c3bb81b6263e06fc88d8d3f07e4a` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/gpg-tui/gpg-tui_0.11.2-1_loongarch64.deb) |
| `grex` | `1.4.6-1` | `loongarch64` | `8331fd714aa4b27d8f990c165b889b2cacf83f5a693422f5447ac8b322cee7d2` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/grex/grex_1.4.6-1_loongarch64.deb) |
| `gron` | `0.7.1-3` | `loongarch64` | `33cee90f52f0f581c789fad7b07a2520d0d815d7566cf2e332ef0156870b0fd7` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/gron/gron_0.7.1-3_loongarch64.deb) |
| `gum` | `2.0.2-3` | `loongarch64` | `15f8082a75db9587d469aa566e94ba2eed78209256146396e9654bbd43a917e9` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/gum/gum_2.0.2-3_loongarch64.deb) |
| `helm-docs` | `1.14.2-1` | `loongarch64` | `8b9b30b5b6188bca85ef87aaa917de7e7966d1d962da33005d43ef13c04b0dfd` | [下载](https://homebrewloongarch64.site/aosc/pool/main/h/helm-docs/helm-docs_1.14.2-1_loongarch64.deb) |
| `hexyl` | `0.17.0-1` | `loongarch64` | `c5eae91a3f3247e380392fac5b17b7205407140c9c9a700a5843bf4b21b77a6c` | [下载](https://homebrewloongarch64.site/aosc/pool/main/h/hexyl/hexyl_0.17.0-1_loongarch64.deb) |
| `hurl` | `8.1.0-1` | `loongarch64` | `8d7a88d7d5947978ea377abe554e07b6785247b6047be9f28ecff0f81357ca30` | [下载](https://homebrewloongarch64.site/aosc/pool/main/h/hurl/hurl_8.1.0-1_loongarch64.deb) |
| `hwatch` | `0.4.2-1` | `loongarch64` | `e1eaf7c3031301471ea41a1e5e33abc3175ea8cb813ff3cd6d7e3beb63f5261f` | [下载](https://homebrewloongarch64.site/aosc/pool/main/h/hwatch/hwatch_0.4.2-1_loongarch64.deb) |
| `igrep` | `1.3.0-1` | `loongarch64` | `a2e96a1252db12c0856003b0806c21acc76a298274470e24998777d5bc8bd00b` | [下载](https://homebrewloongarch64.site/aosc/pool/main/i/igrep/igrep_1.3.0-1_loongarch64.deb) |
| `jaq` | `3.1.2-2` | `loongarch64` | `6d5d73b1a263d054d6a184efe1184ad6aadf92a6dc246240dd92c51973e3a6e8` | [下载](https://homebrewloongarch64.site/aosc/pool/main/j/jaq/jaq_3.1.2-2_loongarch64.deb) |
| `jira-cli` | `1.7.0-2` | `loongarch64` | `7e1b0c93251d2622d9cd43dbfc8ced702422d55998ed9d20d82c9daacf3aabea` | [下载](https://homebrewloongarch64.site/aosc/pool/main/j/jira-cli/jira-cli_1.7.0-2_loongarch64.deb) |
| `jnv` | `0.7.1-1` | `loongarch64` | `a116240ac21fd468b1e1e632576116a5e917fcac9dc3e3eaa085f37991bbe95d` | [下载](https://homebrewloongarch64.site/aosc/pool/main/j/jnv/jnv_0.7.1-1_loongarch64.deb) |
| `k9s` | `0.51.0-1` | `loongarch64` | `7a8ed9b2dcff8c72fe3921bed92638122f36e0912d91668b80720a8d62b917e3` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/k9s/k9s_0.51.0-1_loongarch64.deb) |
| `kube-capacity` | `0.8.0-1` | `loongarch64` | `e3d5657f3c414d3ac9be890fb36d606916dfd88b3122d953e234b69053a75211` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/kube-capacity/kube-capacity_0.8.0-1_loongarch64.deb) |
| `kube-score` | `1.20.0-1` | `loongarch64` | `303f7be1051be4150c861ed1af3e0bab82f6e105f3bf23d7bf3dadaa003d4a14` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/kube-score/kube-score_1.20.0-1_loongarch64.deb) |
| `kubecolor` | `0.0.25-1` | `loongarch64` | `65d134db9d93f5f0eb1a6d0c9b854c74e5325cd0f85fa9b0ca950415d6d995d9` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/kubecolor/kubecolor_0.0.25-1_loongarch64.deb) |
| `kubeconform` | `0.8.0-1` | `loongarch64` | `20b69ab61594540c8ee29dcc9d49457570f868cec66cb2ef3fdc8244a1a6688c` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/kubeconform/kubeconform_0.8.0-1_loongarch64.deb) |
| `kubectl-ai` | `0.0.31-1` | `loongarch64` | `341c2d83c45b836cf3beca746b197b70b1dc3e029dbf604766945cbd340c9c09` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/kubectl-ai/kubectl-ai_0.0.31-1_loongarch64.deb) |
| `kubectl-neat` | `2.0.4-1` | `loongarch64` | `bc75261ccf7bf249a75da9a444a7c81ecd81cbc20d873705a0db8197869d014f` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/kubectl-neat/kubectl-neat_2.0.4-1_loongarch64.deb) |
| `kubectl-tree` | `0.6.0-1` | `loongarch64` | `3d574d9f393fac323cd541e00a8aa7a00dd385ddafe0ea54bf90119c99285ac6` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/kubectl-tree/kubectl-tree_0.6.0-1_loongarch64.deb) |
| `kubeswitch` | `0.9.3-2` | `loongarch64` | `9039d515fc9ba089e3eafd8d1adbf5b0930c10f249affc703ee191eb1f392789` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/kubeswitch/kubeswitch_0.9.3-2_loongarch64.deb) |
| `kustomize` | `5.8.3-1` | `loongarch64` | `4108a4929e17a663ba2f89aa6a32b925f78c8d6b6a42107127b885309d7a5ee5` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/kustomize/kustomize_5.8.3-1_loongarch64.deb) |
| `lazydocker` | `0.25.2-2` | `loongarch64` | `ad69abf36e52cd4edeabe32e6f7570b2464645e9d7176c2d68f5a4b0b3b82c2c` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/lazydocker/lazydocker_0.25.2-2_loongarch64.deb) |
| `lazysql` | `0.7.0-1` | `loongarch64` | `c8a8b78eaeed595897697a0f496d06c4f2fa6609957563c46e8f849ad200d9c0` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/lazysql/lazysql_0.7.0-1_loongarch64.deb) |
| `lf` | `42-3` | `loongarch64` | `4ca72bd37930376661b2eb6f87d764a67995219f857d0204cdb6f17ff2ac6c90` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/lf/lf_42-3_loongarch64.deb) |
| `lhasa` | `0.6.0-1` | `loongarch64` | `32a1d9f0a9d28642ddfb4dfcd97a132e903e9a9a279cc84a7021cb47df458226` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/lhasa/lhasa_0.6.0-1_loongarch64.deb) |
| `libmspack` | `1.12-2` | `loongarch64` | `8ab6d3c0882cfcf64400b4205bce5e11f28dc1dc39cd3bdb1e77b81b91408b04` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/libmspack/libmspack_1.12-2_loongarch64.deb) |
| `libpng` | `1.6.59-3` | `loongarch64` | `4d3256386ab61bfbb98b842f7fda3eb208095f7cd540f8759085d21ac30d230f` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/libpng/libpng_1.6.59-3_loongarch64.deb) |
| `linuxsampler` | `2.4.2-1` | `loongarch64` | `58f86f24f56160c501f819bd2467ca40da38385cec0013e347be82bb93cef67a` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/linuxsampler/linuxsampler_2.4.2-1_loongarch64.deb) |
| `loongvpu-open` | `0.0.0+git20261118.8d952056-6` | `loongarch64` | `d8a48f3f57bbb5d5cb3c986417d5aa40c92c5e91ad81167312eb2990573aac78` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/loongvpu-open/loongvpu-open_0.0.0+git20261118.8d952056-6_loongarch64.deb) |
| `mesa-vulkan-loonggpu` | `26.1.5-1` | `loongarch64` | `3543cc9ea848494b4a2238b212309c39a0a4f119c57e9318e3a843847322e10a` | [下载](https://homebrewloongarch64.site/aosc/pool/main/m/mesa-vulkan-loonggpu/mesa-vulkan-loonggpu_26.1.5-1_loongarch64.deb) |
| `mkcert` | `1.4.4-2` | `loongarch64` | `ecac312b0cd6d555ae32f148b6c749ade51416250d35d99149502714f684daf6` | [下载](https://homebrewloongarch64.site/aosc/pool/main/m/mkcert/mkcert_1.4.4-2_loongarch64.deb) |
| `moar` | `2.19.7-1` | `loongarch64` | `4882f022798f5447a52b4315766e8616296cd113fb7d5a7e880ef910607dd436` | [下载](https://homebrewloongarch64.site/aosc/pool/main/m/moar/moar_2.19.7-1_loongarch64.deb) |
| `muffet` | `2.11.8-1` | `loongarch64` | `d6f74097a63a7926a96c7e6cf4e426ef9d6104231473e2b675ac901b7ab6c0a2` | [下载](https://homebrewloongarch64.site/aosc/pool/main/m/muffet/muffet_2.11.8-1_loongarch64.deb) |
| `navi` | `2.24.0-1` | `loongarch64` | `066b126ec503a0a88ebd4164fa53bd17098d390a30d23d32ad1d0fbcdca7a5e5` | [下载](https://homebrewloongarch64.site/aosc/pool/main/n/navi/navi_2.24.0-1_loongarch64.deb) |
| `nu` | `0.117.0-2` | `loongarch64` | `59652d77d6f4b4290b809d2cd26c4742886b92e010391066a8e430f6afa70c75` | [下载](https://homebrewloongarch64.site/aosc/pool/main/n/nu/nu_0.117.0-2_loongarch64.deb) |
| `oha` | `1.17.0-1` | `loongarch64` | `2bfb3e8164bf007f09abcc9adcbe19b724f80b400155bf265352ae2ff3dc22d7` | [下载](https://homebrewloongarch64.site/aosc/pool/main/o/oha/oha_1.17.0-1_loongarch64.deb) |
| `ov` | `0.55.0-2` | `loongarch64` | `277415179726d7e9c4440fddc111d89a90015028515d63c35351e07c116febfb` | [下载](https://homebrewloongarch64.site/aosc/pool/main/o/ov/ov_0.55.0-2_loongarch64.deb) |
| `plasma-loonggpu-compat` | `1.0.4-1` | `loongarch64` | `2db5b5c21cd93eab9997e25fbd2593e56a9c2aa263c4340790be378b23aad505` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/plasma-loonggpu-compat/plasma-loonggpu-compat_1.0.4-1_loongarch64.deb) |
| `pop` | `0.5.0-1` | `loongarch64` | `c11a8e019262469c68774757bc3711d42eb4ad9aeb5b4b3e2ec9b63905485bc5` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/pop/pop_0.5.0-1_loongarch64.deb) |
| `popeye` | `0.22.1-1` | `loongarch64` | `fd8022894eed6edbad415ca645e36acfcc072c4cd8ce88d42e25dec9dee1f847` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/popeye/popeye_0.22.1-1_loongarch64.deb) |
| `prettyping` | `1.1.0-1` | `all` | `c9cb64f22b6bffd96e17258eb10be8cd66d122559db6d9963fb7b48db0bfe672` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/prettyping/prettyping_1.1.0-1_all.deb) |
| `procs` | `0.14.12-2` | `loongarch64` | `50ba32263de291e4489edd3cbba177281b91b794cf971b9cee535139eba51b70` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/procs/procs_0.14.12-2_loongarch64.deb) |
| `pueue` | `4.0.4-1` | `loongarch64` | `05eaf88ccfd27b9942782e5fb36791b3f8231b61b4397c1d6d51a9a2d53f2329` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/pueue/pueue_4.0.4-1_loongarch64.deb) |
| `pyenv` | `2.8.15-2` | `all` | `77247c8ce808e6d4682d701c1a285b9801afc87f2fb6e5e01931a803ffbd75e7` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/pyenv/pyenv_2.8.15-2_all.deb) |
| `ripgrep-all` | `0.10.10-1` | `loongarch64` | `56fee43e3f032a442f15a99c622431ffff57cf29114131cca2d5388b1c529cf9` | [下载](https://homebrewloongarch64.site/aosc/pool/main/r/ripgrep-all/ripgrep-all_0.10.10-1_loongarch64.deb) |
| `sad` | `0.4.33-1` | `loongarch64` | `337275cf0f077c59d89396f0ef55aaa80357cd5d4ff35140a884e340a517cd93` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/sad/sad_0.4.33-1_loongarch64.deb) |
| `samurai` | `1.3-1` | `loongarch64` | `316e28b808c1a5989138644a8547e062af3b679ca9e344ba96ef356d8b5e57ea` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/samurai/samurai_1.3-1_loongarch64.deb) |
| `sd` | `1.1.0-5` | `loongarch64` | `77da1674cb5607a07211492d4fd3dae4db6a0d8f03ccfc55c909f37b4928af9f` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/sd/sd_1.1.0-5_loongarch64.deb) |
| `shellharden` | `4.3.2-1` | `loongarch64` | `15c8555ca1754ab840df5157904a10c54a54f1afe94fca3c16a667118a126858` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/shellharden/shellharden_4.3.2-1_loongarch64.deb) |
| `skim` | `5.9.0-1` | `loongarch64` | `e533b6e34680bab1f34277847ed67fa9339232ddd0d23021539a83aa677f1d81` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/skim/skim_5.9.0-1_loongarch64.deb) |
| `sops` | `3.13.3-3` | `loongarch64` | `44504a13146587997ec3b4d496d727b4df0d0e1f27006de7678d9a1703550a95` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/sops/sops_3.13.3-3_loongarch64.deb) |
| `speedtest-cli` | `2.1.3-1` | `all` | `bd23476d5eeef374e6c8e9bf56e57d18d8c945d548869aa39287cfc3eea32b58` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/speedtest-cli/speedtest-cli_2.1.3-1_all.deb) |
| `spirv-cross` | `1.4.363.0-6` | `loongarch64` | `2ed598586789f8b3231fcb93fc77bf10b16e136795837e21091e490d37dec2da` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/spirv-cross/spirv-cross_1.4.363.0-6_loongarch64.deb) |
| `staticcheck` | `2026.2.2-2` | `loongarch64` | `7395fdbd041edddb4209bd6b011ba21e73a14959a0569966674483619e980999` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/staticcheck/staticcheck_2026.2.2-2_loongarch64.deb) |
| `stern` | `1.35.0-1` | `loongarch64` | `12d5ca9f2cb4ba3f4e0c28b3ac147bd51d2bed9740d7e825f60e8a00fa285dd0` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/stern/stern_1.35.0-1_loongarch64.deb) |
| `superfile` | `1.6.0-2` | `loongarch64` | `738777939d2e3e9c4164214efc8b5e258c37714fea8ecb6d9a69ca69b283c409` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/superfile/superfile_1.6.0-2_loongarch64.deb) |
| `taplo` | `0.10.0-1` | `loongarch64` | `38474393fb48626301a2b1f38252fbb40537f91b96be5b8ec864816fccd62576` | [下载](https://homebrewloongarch64.site/aosc/pool/main/t/taplo/taplo_0.10.0-1_loongarch64.deb) |
| `tdf` | `0.5.0-3` | `loongarch64` | `a259d65c0f4a6c0a0830f5420ca3d70d878713476e9453b1685b4517e62b7154` | [下载](https://homebrewloongarch64.site/aosc/pool/main/t/tdf/tdf_0.5.0-3_loongarch64.deb) |
| `tectonic` | `0.17.0-1` | `loongarch64` | `95d2d256fccb9398111451195ebd1edf4371deb47d8208ca8b5d19720115350d` | [下载](https://homebrewloongarch64.site/aosc/pool/main/t/tectonic/tectonic_0.17.0-1_loongarch64.deb) |
| `trippy` | `0.13.0-2` | `loongarch64` | `30874bf14ba18c3b46479edf640b5f0cd379a98e032fee85534f3324e71c912b` | [下载](https://homebrewloongarch64.site/aosc/pool/main/t/trippy/trippy_0.13.0-2_loongarch64.deb) |
| `trivy` | `0.76.2-2` | `loongarch64` | `a15510cd1f8c4acf22af23c2d613773ca4ec1c4b6d0c951a37baf1b4e796c186` | [下载](https://homebrewloongarch64.site/aosc/pool/main/t/trivy/trivy_0.76.2-2_loongarch64.deb) |
| `v2raya` | `2.5.15-1` | `loongarch64` | `1af795313d31ac37a72763de26ef8ea0190944b37da07ede8ca85f62b4d745f5` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/v2raya/v2raya_2.5.15-1_loongarch64.deb) |
| `valkey` | `9.1.3-1` | `loongarch64` | `88c13e8fd528d7c978403c8826769a29ecbd63d7efdce1b9b32361b9d6696e5b` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/valkey/valkey_9.1.3-1_loongarch64.deb) |
| `vegeta` | `12.13.0-4` | `loongarch64` | `8dd9dddff3303ba0b8937af6ba41fa7b34c3203c9b2fc5340a27882b15841d1c` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/vegeta/vegeta_12.13.0-4_loongarch64.deb) |
| `visidata` | `3.5-1` | `all` | `790d6e3c9855676aac5c5125ca0d5c0b8c2c1ae7c63efa94c689be0ff78f4ca8` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/visidata/visidata_3.5-1_all.deb) |
| `vkgl-loonggpu` | `0.1.35-2` | `loongarch64` | `9130cfa2582c5bac438c313b100b3f352e7bce421079c404d63812ada03bbb25` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/vkgl-loonggpu/vkgl-loonggpu_0.1.35-2_loongarch64.deb) |
| `watchexec` | `2.8.0-2` | `loongarch64` | `977332d9b25705559403c8cc7b8fddfa6bd86e63b2ece9ad7782dbc3f3641214` | [下载](https://homebrewloongarch64.site/aosc/pool/main/w/watchexec/watchexec_2.8.0-2_loongarch64.deb) |
| `wowtype` | `0.4.0-1` | `loongarch64` | `581187832bd6eadaa8bdbcaefb52c46a4724757b88033950af654ca097ca0fba` | [下载](https://homebrewloongarch64.site/aosc/pool/main/w/wowtype/wowtype_0.4.0-1_loongarch64.deb) |
| `wrk` | `4.2.0-1` | `loongarch64` | `c30ed02020a5fafa24b233ede789dfba2332be70b7dd62f111711c3f2f65879d` | [下载](https://homebrewloongarch64.site/aosc/pool/main/w/wrk/wrk_4.2.0-1_loongarch64.deb) |
| `xh` | `0.26.3-1` | `loongarch64` | `e09ac2f1866f85ba79cd3078af4382ec2a76de85aa01508c6ace1884dd4181fa` | [下载](https://homebrewloongarch64.site/aosc/pool/main/x/xh/xh_0.26.3-1_loongarch64.deb) |
| `xsv` | `0.13.0-4` | `loongarch64` | `c189016208453ff747dfbb5a8bd814bce7cb9fb6608de714d04c5353b59b5325` | [下载](https://homebrewloongarch64.site/aosc/pool/main/x/xsv/xsv_0.13.0-4_loongarch64.deb) |
| `yamllint` | `1.38.0-2` | `all` | `4f02f247e5833fcd2d6c0da1f6e8bb0ee2205aa1e7d047402a293049b65caedc` | [下载](https://homebrewloongarch64.site/aosc/pool/main/y/yamllint/yamllint_1.38.0-2_all.deb) |
| `zerotier-one` | `1.16.2-3` | `loongarch64` | `1c81bc8752334a32c4b8fe546be6f770ac7c7aafeb7eb41963b9845bb0c51ea5` | [下载](https://homebrewloongarch64.site/aosc/pool/main/z/zerotier-one/zerotier-one_1.16.2-3_loongarch64.deb) |
| `zizmor` | `1.32.0-1` | `loongarch64` | `6d0eeeb113e327476a8737c3f4a5d14a41347a4ceb3f7df5794b004b915d92a2` | [下载](https://homebrewloongarch64.site/aosc/pool/main/z/zizmor/zizmor_1.32.0-1_loongarch64.deb) |

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

* 上游最新稳定版（当前 7.3.4）；
* **AOSC OS 的 LoongArch 补丁全部打上**（450 个补丁中可应用的 355 个 + 55 个上游已合并；
  其余 40 个为 RISC-V/x86/Surface/Rust 等无关补丁）；
* 16K 页 + `PREEMPT_RT`；
* 两个变体：`gcc`（`KCFLAGS=-O3`）与 `clang`（`LLVM=1` + `CONFIG_LTO_CLANG_FULL`）；
* 打包为 AOSC 风格 `loongarch64` deb，含 DKMS 钩子（`loonggpu` 显卡驱动会随内核自动重建）。

```bash
sudo apt install linux-kernel-mainline-16k-rt-7.3.4-gcc-o3
sudo apt install linux-kernel-mainline-16k-rt-7.3.4-clang-lto
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
