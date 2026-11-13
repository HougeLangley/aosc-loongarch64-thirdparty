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
| `phase3-cumulative.patch` | 固定第三方 HEAD 到当前研究源码的完整补丁 | `a6bb9a964ef8cd17287cc5eea3d4719fd025a9308096973f16d0171b142791df` |
| `phase3-vmid-lru.patch` | phase2 到 phase3 的单文件 VMID 等待修复 | `340f73deff3627bb49b949c8dba1fa20663af28616db14c424a53fb38e8c28f6` |
| `audit.json` | 最终 TU、编译选项、modpost、vermagic、未解析符号和重定位审计 | 见实际文件；KO SHA 在文件内 |

最终隔离构建的 KO SHA-256 为
`71e9e8936a1950f1636143621c1ff5861bd3b704d79f3989a40adff6fde7e169`，
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

## 仍未放行的问题

- **legacy recovery 未闭合：**默认 `recover_fence_fix=0` 的 guilty-ring 路径仍需重新审查
  pending-list、credits 和 fence completion；本阶段没有扩大为恢复框架重写。
- **生产硬冲突：**本机 `00:06.0 [0014:7a25]` 已绑定 `loonggpu`，
  `00:06.1 [0014:7a36]` 已绑定 `loonggpu-dc`。研究模块还声明相同 PCI alias，
  导出裸全局 `loongson_dc_pdev`，并使用相同 DRM/module name `gsgpu`。
- 第三方项目自身还记录 Y 镜像、黑带、IBO 未实现、fault 146、纹理和 line 错误。
  当前公开快照缺少部分原始提交日志，不能把历史记录当作本补丁的真机证据。

## 隔离复现原则

原第三方树以 6.6/6.6.52 为基线，导出快照缺少原 `build-dc.sh`。复现时必须：

1. 只导出 `src/kernel/tree-stride2`，在独立目录应用 `phase3-cumulative.patch`。
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

先解决或明确废弃 legacy recovery，再完成生产解绑定、命名/导出隔离和回退设计。
只有独立可恢复测试机及明确维护授权后，才讨论 probe、fence、
像素、VMID 饱和、超时恢复和显示验证。compile PASS 不构成这些授权或证据。

第三方 gsgpu 内核源采用 GPL-2.0；本目录补丁为其内核 API 移植研究，不包含厂商闭源用户态、
固件或预编译模块。
