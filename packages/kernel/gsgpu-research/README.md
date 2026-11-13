# LG110 开源 gsgpu 的 7.3.4 compile-only 研究

> **研究补丁，不是可安装驱动。不得在生产机加载，不得与 loonggpu 同时 probe。**

本目录保存对第三方 [leesin872/lg110-open-gpu](https://github.com/leesin872/lg110-open-gpu)
固定快照的 7.3.4 移植结果。输入 HEAD 为
`db2c49b86b9459f44abe73b7c2f2202bdc031cad`（2026-09-15 的单个 root 导出提交），
不是本仓库自行声称的原生驱动完成品。

## 当前状态

- 目标内核：`7.3.4-mainline-16k-rt-clang-lto`。
- Clang/LLD 22.1.8、16K、PREEMPT_RT、full LTO、WERROR 均保留。
- 最终 60/60 个预期源码 TU 全部重编，另有生成的 `gsgpu.mod.o`；61/61 条 CC
  命令都带 WERROR 和最终生效的 `-flto`。
- compiler warning=0、MODPOST warning=0、MODPOST=1、KO 链接=1、最终 `rc=0`。
- 未发布 KO 或 deb，没有安装、`insmod/modprobe`、硬件 probe、Mesa 构建或真机渲染证据。
- 没有使用 llvmpipe/lavapipe 代替硬件路径。

**结论仅为 compile/MODPOST 通过。运行时、真机和生产部署仍然 NO-GO。**

## 文件

| 文件 | 用途 | SHA-256 |
|---|---|---|
| `phase5-cumulative.patch` | 固定第三方 HEAD 到当前研究源码的完整补丁 | `24c8d8c45542d356fa45f7dcfcccfdc90611901c917ac96efcba64d597916808` |
| `phase5-isolation.patch` | phase4 到 phase5 的名称/符号隔离与 init 回滚修复 | `366313f7b091c718da931f1e1fa1dada034de8601a47e05892a54458e3a28724` |
| `audit.json` | 最终 TU、编译选项、modpost、vermagic、未解析符号和重定位审计 | 见实际文件；KO SHA 在文件内 |

最终隔离构建的 KO SHA-256 为
`7f2bf162e1aed3d715b2a88074bde7d5d089a747c0c70d5d4b9baf30dd08ce1d`，
但**二进制不随仓库发布**。该哈希用于核对研究日志，不提供下载或安装入口。

## 已处理的主要 API/语义问题

移植涉及 aperture、DRM scheduler args/credits/client ID、TTM allocation flags、
GEM 生命周期、fbdev probe、gpu_buddy、trace 重包含、DC/bridge/I2C 等 7.3.4 API 变化。
完整补丁修改 46 个已有文件，没有新增或删除源码文件。

第一版 compile PASS 后，静态复核又修正了以下不能由编译器发现的问题：

1. LOW/VERY_LOW 错映射为 KERNEL；现映射到 `DRM_SCHED_PRIORITY_LOW`。
2. ring priority 沿用旧枚举方向；现同步反转 get/put 比较和衰减循环。
3. recover 后误报 `NO_HANG`；现区分未 hang、实际重置成功、恢复禁用和重置失败，
   分别对应 `NO_HANG`、`RESET` 和 `ENODEV`。
4. `drm_sched_start(..., true)` 把旧 bool 变成正 errno；现传实际恢复结果 `r`，
   成功为 0，失败为负 errno。

C5 没有机械地把 `ttm_bo_put` 换成 GEM put：创建时设置 `base.funcs`，GEM free 经
`ttm_bo_fini` 进入 TTM release，静态正常路径未见同对象递归释放或 double-free。
运行时引用计数、并发 close 和 parent/shadow 链仍未验证。

phase3 进一步按同版本 AMDGPU 的 VMID 策略移除了临时的 all-fence 等待：从 MRU 端扫描，
全部繁忙时只缓存并等待 LRU 单条 fence。PASID 延迟释放仍保留其本来就需要等待全部 fence
的独立数组路径。这样不再把无关 VMID 的长等待耦合到当前 ring，但 VMID 饱和和恢复仍未真机验证。

phase4 删除了不完整的 legacy recovery 及两个实验开关，统一为所有 ring 的
`drm_sched_stop` → force completion → reset → `drm_sched_start(r)`。独立复核发现的三个后续问题
也已修复：recovery disabled 时对 guilty scheduler 显式 stop/start(-ENODEV)；VRAM 恢复失败不再
返回正 1；`free_job` 调用 `drm_sched_job_cleanup()`。这些结论只覆盖所审查的调度生命周期，
不扩大为整个模块无泄漏或硬件 reset 可用。

phase5 将 DRM/PCI/fence 名称统一为 `gsgpu-research`，把裸导出改为 `gsgpu_research_dc_pdev`，
并修复 init 的 DC/KMS/fence/sync 回滚。默认及非1参数在任何 PCI 注册或硬件访问前返回 `-ENODEV`；
只有严格 `exp_hw_support=1` 才进入研究路径。独立定点静态复核通过，但用户态精确名称匹配尚未适配。

## 仍未放行的问题

- **没有可用硬件 reset 原语：**当前 `has_hw_reset` 的 fail-closed 路径仍返回 `-ENODEV`；
  调度资源可以按核心约定清理，不代表挂起引擎、VM/VRAM 或显示能够恢复。LG100/LG200 分类、
  不可达的 `0x7c` magic 写入及本机只读证据见 [RESET.md](RESET.md)。
- **生产 PCI 冲突：**本机 `00:06.0 [0014:7a25]` 已绑定 `loonggpu`，
  `00:06.1 [0014:7a36]` 已绑定 `loonggpu-dc`。研究模块仍声明相同 PCI alias，禁止同时 probe。
  phase5 已隔离 DRM/fence 名称和裸导出符号，但这不等于设备隔离。
- 第三方项目自身还记录 Y 镜像、黑带、IBO 未实现、fault 146、纹理和 line 错误。
  当前公开快照缺少部分原始提交日志，不能把历史记录当作本补丁的真机证据。

## 隔离复现原则

原第三方树以 6.6/6.6.52 为基线，导出快照缺少原 `build-dc.sh`。复现时必须：

1. 只导出 `src/kernel/tree-stride2`，在独立目录应用 `phase5-cumulative.patch`。
2. 将仓内三个 staging 头放到**目标内核副本**的对应路径，而不是生产 headers：
   - `include/uapi/drm/gsgpu_drm.h`
   - `include/drm/gsgpu_family_type.h`
   - `drivers/gpu/drm/gsgpu/include/gsgpu_trace.h`
3. 对已生成的 7.3.4 构建树使用 overlayfs 或独立 CoW/完整副本；禁止硬链接复用构建输出。
4. 仅执行 `M=<scratch-module> MO=<scratch-out> ARCH=loongarch LLVM=1 -j1 modules`，
   保留 full LTO/WERROR，不删对象、不跳过 modpost、不伪造导出。
5. 验收 60 个源 TU、生成单元、modpost、vermagic、未解析符号和 ELF 重定位后立即停止。

本机研究使用 overlay lower/upper/work 隔离；前后原树均为 200,411 项，元数据清单哈希均为
`55eb2893a618bea45e52e2eeb31cba2acfdaf7096c33555856494d77b959b806`。
元数据哈希不是全树逐文件内容哈希，不能扩大解释。

## 后续门槛

先明确可恢复的硬件 reset 原语及 fail-closed 边界，再完成独立测试环境的生产解绑定、
用户态 `gsgpu-research` 名称适配和回退设计。只有独立可恢复测试机及明确维护授权后，才讨论 probe、fence、
像素、VMID 饱和、超时恢复和显示验证。compile PASS 不构成这些授权或证据。

第三方 gsgpu 内核源采用 GPL-2.0；本目录补丁为其内核 API 移植研究，不包含厂商闭源用户态、
固件或预编译模块。
