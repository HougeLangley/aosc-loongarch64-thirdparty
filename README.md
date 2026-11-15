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
当前列出 **79 个最新 deb 条目、79 个不同包名**；索引共保留 85 个 deb（含历史版本），每个包只列最新版本。
旧版本只保留有限的回滚副本，不在 README 罗列。APT 默认选择可安装的最新版本。
`mesa-vulkan-loonggpu` 仍只是已废弃的 RADV 存档，不代表 LG110 可用原生 Vulkan。

| 软件包 | 版本 | 架构 | SHA-256 | deb |
|---|---|---|---|---|
| `age` | `1.3.2-2` | `loongarch64` | `1d84c3226b7de0891a032953f0d8073ffe6c503c19ff0d627d6ff2233da40c8e` | [下载](https://homebrewloongarch64.site/aosc/pool/main/a/age/age_1.3.2-2_loongarch64.deb) |
| `bandwhich` | `0.23.1-1` | `loongarch64` | `526b2d043b1e1f2c491c9ff76ec9e6b1f1bf5913d3b261945853ed72a665c109` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/bandwhich/bandwhich_0.23.1-1_loongarch64.deb) |
| `bashtop` | `0.9.25-1` | `all` | `22d343ee1635463a9dff222f3ad41565adcd10adcfdb05367475d757cdf67839` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/bashtop/bashtop_0.9.25-1_all.deb) |
| `bat-extras` | `20200408-1` | `all` | `973bf00bdd948230f922490fced3d1b9815b71990771961834d1b33ac148001d` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/bat-extras/bat-extras_20200408-1_all.deb) |
| `bmake` | `20260912-3` | `loongarch64` | `b7d6fc3d23060b31b95799db9d850b851aa4f39811a5803d2ef75ea3bf738464` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/bmake/bmake_20260912-3_loongarch64.deb) |
| `brew-ui-linux` | `0.1.0-5` | `loongarch64` | `f31a56110f420390f32cb2f795b8984109f41187382cbd4cc7e374184c30f481` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/brew-ui-linux/brew-ui-linux_0.1.0-5_loongarch64.deb) |
| `broot` | `1.62.0-1` | `loongarch64` | `cd989fee3a2c1ccbc142636c56f9855594bc2e9b14054bbf2059d5495e4cea8e` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/broot/broot_1.62.0-1_loongarch64.deb) |
| `btrbk` | `0.32.7-1` | `all` | `706a7edc85be026beec1e3fdd7418a7285f92223f2cc9c9f5b9fab6c9e771846` | [下载](https://homebrewloongarch64.site/aosc/pool/main/b/btrbk/btrbk_0.32.7-1_all.deb) |
| `codespell` | `2.4.3-1` | `all` | `d4e23975944ab061c2ac21a2a3d40c12128041e2786c06d662ab18eeb3ee882e` | [下载](https://homebrewloongarch64.site/aosc/pool/main/c/codespell/codespell_2.4.3-1_all.deb) |
| `csvlens` | `0.15.1-1` | `loongarch64` | `4455040c5915b3320e04f5ff25d21045fa5593662c2ec7c3d4453141f69c4c89` | [下载](https://homebrewloongarch64.site/aosc/pool/main/c/csvlens/csvlens_0.15.1-1_loongarch64.deb) |
| `curlie` | `1.8.2-2` | `loongarch64` | `81067e8c5bc35003e8d757e893cc8b2faaafcb48a56f85495146bf4db822cb94` | [下载](https://homebrewloongarch64.site/aosc/pool/main/c/curlie/curlie_1.8.2-2_loongarch64.deb) |
| `dua-cli` | `3.0.3-1` | `loongarch64` | `0d16dea59a4f4d1d716440eaa16cc467b427e0a0fdbe3d8c0602ff6f8338073f` | [下载](https://homebrewloongarch64.site/aosc/pool/main/d/dua-cli/dua-cli_3.0.3-1_loongarch64.deb) |
| `dysk` | `3.8.2-1` | `loongarch64` | `247e01aeb68b5d7e9621fc8a7c3e34c9e6b51deacf702a07fdb332aa9607d077` | [下载](https://homebrewloongarch64.site/aosc/pool/main/d/dysk/dysk_3.8.2-1_loongarch64.deb) |
| `entr` | `5.7-1` | `loongarch64` | `5a9c6cbaaf75d67c63e771639a297753a9477f3565620cdfa035d6f32eb600c8` | [下载](https://homebrewloongarch64.site/aosc/pool/main/e/entr/entr_5.7-1_loongarch64.deb) |
| `fclones` | `0.35.0-2` | `loongarch64` | `a18aae2aaed64cd8a08e29cc1d8d35b6032793ca8c15123af7368680952418e1` | [下载](https://homebrewloongarch64.site/aosc/pool/main/f/fclones/fclones_0.35.0-2_loongarch64.deb) |
| `freeze` | `0.2.2-1` | `loongarch64` | `c7740641af43dc3ae0db387c9c267e1057395caaf5eebb388eadaee7ba9a1948` | [下载](https://homebrewloongarch64.site/aosc/pool/main/f/freeze/freeze_0.2.2-1_loongarch64.deb) |
| `fx` | `40.0.1-1` | `loongarch64` | `002c89ebd75ae62b5603f2e86ebbf811c53807699fa96c14c2c100c79d7ee817` | [下载](https://homebrewloongarch64.site/aosc/pool/main/f/fx/fx_40.0.1-1_loongarch64.deb) |
| `git-branchless` | `0.11.1-3` | `loongarch64` | `c7f3a8f1e7a8a6d1af3b3c047ba2573781f6040d53d8023f06a9ffd8755f313b` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/git-branchless/git-branchless_0.11.1-3_loongarch64.deb) |
| `git-sizer` | `1.6.0-3` | `loongarch64` | `670780953f24db03b6fa26aa832e25aa2272d41ab8409868d22b812c4ef6d4dc` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/git-sizer/git-sizer_1.6.0-3_loongarch64.deb) |
| `gitleaks` | `8.30.1-2` | `loongarch64` | `46f339a365aedecc15997c0ecd8188393a080e4408d22dc802d1c19cd207164f` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/gitleaks/gitleaks_8.30.1-2_loongarch64.deb) |
| `gofumpt` | `0.12.0-2` | `loongarch64` | `586a183266a92be1d0650bbf5fc6578d425747075a859436ba9f6a1a762b12b4` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/gofumpt/gofumpt_0.12.0-2_loongarch64.deb) |
| `golangci-lint` | `2.15.0-3` | `loongarch64` | `cd45839f14cb8d6616a3681ea6c039238203492b01042c91c1ebe675a60a20fd` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/golangci-lint/golangci-lint_2.15.0-3_loongarch64.deb) |
| `gpg-tui` | `0.11.2-1` | `loongarch64` | `08bfc557c3d5e12da63ec8c4119c5e22420481fee3ff9b599447fbf5c28af96b` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/gpg-tui/gpg-tui_0.11.2-1_loongarch64.deb) |
| `gron` | `0.7.1-2` | `loongarch64` | `f7fff1b40814c5493c31173f198afaa9432ca9db0bfbe395104a51ead783ff80` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/gron/gron_0.7.1-2_loongarch64.deb) |
| `gum` | `2.0.2-3` | `loongarch64` | `a789bc467b90c97442ae995260abd5329ff5cce40de12ddb72539c1ec43f571f` | [下载](https://homebrewloongarch64.site/aosc/pool/main/g/gum/gum_2.0.2-3_loongarch64.deb) |
| `hexyl` | `0.17.0-1` | `loongarch64` | `c46033fb779ba302359b90598b3d8da6572c00d55945527c74003383f7b437a1` | [下载](https://homebrewloongarch64.site/aosc/pool/main/h/hexyl/hexyl_0.17.0-1_loongarch64.deb) |
| `hurl` | `8.1.0-1` | `loongarch64` | `3774efbb9a8d45f1720ea6359228a8e0ac66cd4f0279a7e2296141bf481bb63a` | [下载](https://homebrewloongarch64.site/aosc/pool/main/h/hurl/hurl_8.1.0-1_loongarch64.deb) |
| `hwatch` | `0.4.2-1` | `loongarch64` | `477f3489b6c019f04137067a0c68badc9f790f22d87f089e81c1e50610df79dd` | [下载](https://homebrewloongarch64.site/aosc/pool/main/h/hwatch/hwatch_0.4.2-1_loongarch64.deb) |
| `igrep` | `1.3.0-1` | `loongarch64` | `31d2567596aa814855b2df4ddf79d90bc06773516544cddc7e2a6e49029b83bc` | [下载](https://homebrewloongarch64.site/aosc/pool/main/i/igrep/igrep_1.3.0-1_loongarch64.deb) |
| `jaq` | `3.1.2-2` | `loongarch64` | `ffcd0b4f85ecedad23a8dfa0218673e77a147b069e6fe29d4e95db14024fba47` | [下载](https://homebrewloongarch64.site/aosc/pool/main/j/jaq/jaq_3.1.2-2_loongarch64.deb) |
| `k9s` | `0.51.0-1` | `loongarch64` | `640b55b71457a3999faa6d1f99337f90f4895dd0a2daf279d4fefaf252c6097b` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/k9s/k9s_0.51.0-1_loongarch64.deb) |
| `kustomize` | `5.8.3-1` | `loongarch64` | `e3103a4b4389e9c9d9cd32101e00e5c3c250ec959a5d3ebebc19db5529d67ff2` | [下载](https://homebrewloongarch64.site/aosc/pool/main/k/kustomize/kustomize_5.8.3-1_loongarch64.deb) |
| `lazydocker` | `0.25.2-2` | `loongarch64` | `e297aec7d560ebaa831859ae8bddf368786efe511bfa2c052bb8ab81b7960296` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/lazydocker/lazydocker_0.25.2-2_loongarch64.deb) |
| `lf` | `42-3` | `loongarch64` | `9f365c68fb23c9a81ba84ab3cec63330570e9dfe4daa043008892fd41ddfeea7` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/lf/lf_42-3_loongarch64.deb) |
| `lhasa` | `0.6.0-1` | `loongarch64` | `773c0bc859c0974c14ff1bfbd2632a4644c0d8ffa43a022646da4a9317f21c57` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/lhasa/lhasa_0.6.0-1_loongarch64.deb) |
| `libmspack` | `1.12-2` | `loongarch64` | `fd1360cad94e9e04de080647e0686f848b3c58f8038a1b62de6cc7c3ce8168c3` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/libmspack/libmspack_1.12-2_loongarch64.deb) |
| `libpng` | `1.6.59-3` | `loongarch64` | `4d3256386ab61bfbb98b842f7fda3eb208095f7cd540f8759085d21ac30d230f` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/libpng/libpng_1.6.59-3_loongarch64.deb) |
| `linuxsampler` | `2.4.2-1` | `loongarch64` | `6b6a13524ed44e0c493dd9dc594181ac7569150ab822079754550969c4b4f7d8` | [下载](https://homebrewloongarch64.site/aosc/pool/main/l/linuxsampler/linuxsampler_2.4.2-1_loongarch64.deb) |
| `mesa-vulkan-loonggpu` | `26.1.5-1` | `loongarch64` | `3543cc9ea848494b4a2238b212309c39a0a4f119c57e9318e3a843847322e10a` | [下载](https://homebrewloongarch64.site/aosc/pool/main/m/mesa-vulkan-loonggpu/mesa-vulkan-loonggpu_26.1.5-1_loongarch64.deb) |
| `mkcert` | `1.4.4-2` | `loongarch64` | `5bec4afdb3a68c127c03d3690ab97c203e0874bc7481b1680f59797444342b5c` | [下载](https://homebrewloongarch64.site/aosc/pool/main/m/mkcert/mkcert_1.4.4-2_loongarch64.deb) |
| `moar` | `2.19.7-1` | `loongarch64` | `f732b07ff071977633dcf70fb234c34acc0ab81fff47db7ea42412c0871ba216` | [下载](https://homebrewloongarch64.site/aosc/pool/main/m/moar/moar_2.19.7-1_loongarch64.deb) |
| `navi` | `2.24.0-1` | `loongarch64` | `3f519626c914eacf5279d0801b075bae2af363c2633b3a1fefad711ec79b26c1` | [下载](https://homebrewloongarch64.site/aosc/pool/main/n/navi/navi_2.24.0-1_loongarch64.deb) |
| `oha` | `1.17.0-1` | `loongarch64` | `a1c845299747557bc7bff5039e791fb7904a9997985b5b9d6e833a4675fa6f68` | [下载](https://homebrewloongarch64.site/aosc/pool/main/o/oha/oha_1.17.0-1_loongarch64.deb) |
| `ov` | `0.55.0-2` | `loongarch64` | `d21b0da33dcd682b973e980d700bbf5f315c37eec4af7c6c42e26886ddfe2282` | [下载](https://homebrewloongarch64.site/aosc/pool/main/o/ov/ov_0.55.0-2_loongarch64.deb) |
| `plasma-loonggpu-compat` | `1.0.4-1` | `loongarch64` | `2db5b5c21cd93eab9997e25fbd2593e56a9c2aa263c4340790be378b23aad505` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/plasma-loonggpu-compat/plasma-loonggpu-compat_1.0.4-1_loongarch64.deb) |
| `pop` | `0.5.0-1` | `loongarch64` | `68d06378a5945e6107336f99e11d757474924eb8e29a4ebcac62e0306ba2f2fd` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/pop/pop_0.5.0-1_loongarch64.deb) |
| `prettyping` | `1.1.0-1` | `all` | `ab3c7076a17c10333ff4561402f93d0979a26e56bc3e8ad4b978317c455a2fea` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/prettyping/prettyping_1.1.0-1_all.deb) |
| `procs` | `0.14.12-1` | `loongarch64` | `4192e6f29d25617eac468664f99a861d6dd4cc03d8ec810d24d910ce3d98d4f7` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/procs/procs_0.14.12-1_loongarch64.deb) |
| `pueue` | `4.0.4-1` | `loongarch64` | `508d843c6407f55766ce857e7e885e1c458a9e5dc74da7e2ae90739d5bba0f86` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/pueue/pueue_4.0.4-1_loongarch64.deb) |
| `pyenv` | `2.8.14-2` | `all` | `34515f7397e162a085892971404d5920201b82aece9ef081e84f8efc7936e6e1` | [下载](https://homebrewloongarch64.site/aosc/pool/main/p/pyenv/pyenv_2.8.14-2_all.deb) |
| `ripgrep-all` | `0.10.10-1` | `loongarch64` | `89100a80964126c0c20bcc0c89a555fae6a8dc0d943a308e8d4d8459103fa9c1` | [下载](https://homebrewloongarch64.site/aosc/pool/main/r/ripgrep-all/ripgrep-all_0.10.10-1_loongarch64.deb) |
| `sad` | `0.4.33-1` | `loongarch64` | `3e15789267ac2271b780a45b43137662d5e7c44824a52ef50dbdd988d4daef0c` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/sad/sad_0.4.33-1_loongarch64.deb) |
| `samurai` | `1.3-1` | `loongarch64` | `3c6f441f8db059994f1abaccf3c617da94786bd9fea3ab872c33cbae93274251` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/samurai/samurai_1.3-1_loongarch64.deb) |
| `sd` | `1.1.0-5` | `loongarch64` | `ef0848067b81646fa107aab8c6b78e2a15c45d787023f3dfa23b8af0c2da56e0` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/sd/sd_1.1.0-5_loongarch64.deb) |
| `shellharden` | `4.3.2-1` | `loongarch64` | `6254d2768d6abff708dc5c57075b679cebd4d9568460ed2f444040860e9d7f9a` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/shellharden/shellharden_4.3.2-1_loongarch64.deb) |
| `skim` | `5.9.0-1` | `loongarch64` | `142ebc1be6e60a9159cb3b3a11edbb8c1691240c8355c875ecb1bf2b92c8e37e` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/skim/skim_5.9.0-1_loongarch64.deb) |
| `sops` | `3.13.3-3` | `loongarch64` | `01614ae992b2ad4e08ed39053ce03c7cb53689b64c09d20ea353c11829e52556` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/sops/sops_3.13.3-3_loongarch64.deb) |
| `speedtest-cli` | `2.1.3-1` | `all` | `f28f32d7bed597c710c2260067eef82fd6cf7f24d6eeb10e676a6810819b7214` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/speedtest-cli/speedtest-cli_2.1.3-1_all.deb) |
| `spirv-cross` | `1.4.363.0-6` | `loongarch64` | `6ebf133b693b5c56f7cb698eada3c390e11ab9438c8f4d0f958f35af952a1a41` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/spirv-cross/spirv-cross_1.4.363.0-6_loongarch64.deb) |
| `staticcheck` | `0.8.2-2` | `loongarch64` | `a7d938499d18d420e7815b2f00477578a4106ab0aa34b472987bd4ae3cb01ca1` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/staticcheck/staticcheck_0.8.2-2_loongarch64.deb) |
| `superfile` | `1.6.0-2` | `loongarch64` | `019fdadec61325a288f943d644b4a01d0c0ca767f9d99e857b54ea3ec3da2d4a` | [下载](https://homebrewloongarch64.site/aosc/pool/main/s/superfile/superfile_1.6.0-2_loongarch64.deb) |
| `taplo` | `0.10.0-1` | `loongarch64` | `fa9a0b0d214fdce07ed44e4369f606836accd5ca73519e6572f4c18f4e1884ab` | [下载](https://homebrewloongarch64.site/aosc/pool/main/t/taplo/taplo_0.10.0-1_loongarch64.deb) |
| `tdf` | `0.5.0-2` | `loongarch64` | `b249f27735a9adf0971c3be40583ab392ec7cb539c0dcc11ef20b536fdc64459` | [下载](https://homebrewloongarch64.site/aosc/pool/main/t/tdf/tdf_0.5.0-2_loongarch64.deb) |
| `tectonic` | `0.17.0-1` | `loongarch64` | `f3c1e852825ef2360b79c9717943c623dd71614a84ab18fe8f0b9653dd775a70` | [下载](https://homebrewloongarch64.site/aosc/pool/main/t/tectonic/tectonic_0.17.0-1_loongarch64.deb) |
| `trippy` | `0.13.0-2` | `loongarch64` | `2f863e6694708da9bf38096151f231530eb25ad8f76dc24b2b942d92eaead67c` | [下载](https://homebrewloongarch64.site/aosc/pool/main/t/trippy/trippy_0.13.0-2_loongarch64.deb) |
| `trivy` | `0.76.2-2` | `loongarch64` | `7da3410a08d19682b28928b286b10c353f9320f7561f085bc6ddfec59955b4e3` | [下载](https://homebrewloongarch64.site/aosc/pool/main/t/trivy/trivy_0.76.2-2_loongarch64.deb) |
| `v2raya` | `2.5.15-1` | `loongarch64` | `9e827366f7fc6465f89d2de98c84fecbef1f7ee1f87096572226016836779855` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/v2raya/v2raya_2.5.15-1_loongarch64.deb) |
| `valkey` | `9.1.3-1` | `loongarch64` | `571d5c0ae79d1225ea2bce46c05cbc40aefb6d640bd4f66c46e712f913913a86` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/valkey/valkey_9.1.3-1_loongarch64.deb) |
| `vegeta` | `12.13.0-3` | `loongarch64` | `203f2ff2828556e9e7b0acd1cea9531bbc4011eecbb1d33c251c2080a926e1b9` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/vegeta/vegeta_12.13.0-3_loongarch64.deb) |
| `visidata` | `3.5-1` | `all` | `13f94f914e1d8f15dc916882d45e66ed8badb3470d20ab28cb5414fba770ced4` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/visidata/visidata_3.5-1_all.deb) |
| `vkgl-loonggpu` | `0.1.35-2` | `loongarch64` | `9130cfa2582c5bac438c313b100b3f352e7bce421079c404d63812ada03bbb25` | [下载](https://homebrewloongarch64.site/aosc/pool/main/v/vkgl-loonggpu/vkgl-loonggpu_0.1.35-2_loongarch64.deb) |
| `watchexec` | `2.8.0-2` | `loongarch64` | `f208ba6124acb7a38fff3a1facd8374a0e94623e45e5c30ae6c142bcee097b1c` | [下载](https://homebrewloongarch64.site/aosc/pool/main/w/watchexec/watchexec_2.8.0-2_loongarch64.deb) |
| `wowtype` | `0.4.0-1` | `loongarch64` | `0ea8deecb807aafa400c1324464ed8eee78bcfab1b76fad44d9cf29eea35df93` | [下载](https://homebrewloongarch64.site/aosc/pool/main/w/wowtype/wowtype_0.4.0-1_loongarch64.deb) |
| `wrk` | `4.2.0-1` | `loongarch64` | `96e4e61dce0105ec066d302317a155c1fe5732289d85d0dd52a56c49a531dd2b` | [下载](https://homebrewloongarch64.site/aosc/pool/main/w/wrk/wrk_4.2.0-1_loongarch64.deb) |
| `xh` | `0.26.3-1` | `loongarch64` | `8d8a2d2c9d766aa27945cc7fd39c7cb806c1e5eadb5cfbad4123b5249e53e530` | [下载](https://homebrewloongarch64.site/aosc/pool/main/x/xh/xh_0.26.3-1_loongarch64.deb) |
| `xsv` | `0.13.0-1` | `loongarch64` | `29d365afa193b24f3034314fa2085b221cfa8e00c1d755b69b29986b2ab81be1` | [下载](https://homebrewloongarch64.site/aosc/pool/main/x/xsv/xsv_0.13.0-1_loongarch64.deb) |
| `yamllint` | `1.38.0-2` | `all` | `16423e21c7e53d6bc965452dce0f80df725fb645bd467ecf477517ec3bbfead9` | [下载](https://homebrewloongarch64.site/aosc/pool/main/y/yamllint/yamllint_1.38.0-2_all.deb) |
| `zerotier-one` | `1.16.2-3` | `loongarch64` | `1c81bc8752334a32c4b8fe546be6f770ac7c7aafeb7eb41963b9845bb0c51ea5` | [下载](https://homebrewloongarch64.site/aosc/pool/main/z/zerotier-one/zerotier-one_1.16.2-3_loongarch64.deb) |
| `zizmor` | `1.32.0-1` | `loongarch64` | `6f8f425548201fcd314b756e1245a5b64bbeca3220fca65c0152b3ac5a784579` | [下载](https://homebrewloongarch64.site/aosc/pool/main/z/zizmor/zizmor_1.32.0-1_loongarch64.deb) |

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
