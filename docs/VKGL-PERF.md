# LG110 vkgl 性能研究

## 结论先行

当前 1080p FIFO 的瓶颈不在编译器或 shader 优化，而在 **WSI/合成器/DRM 提交等待**。
已实测的 4ms poll 切片、`glFinish`/EGL fence、clear 合并、uniform/UBO 等方向均未带来
可复现收益，不再重复。禁止使用 llvmpipe/lavapipe；只接受 vkgl（LG110）路径。

## 当前栈

- GPU：LoongGPU LG110，`pm_dpm_sclk` 最高档 496MHz（372/434/496，运行在 496）。
- 驱动：DKMS `loonggpu` 1.0.2，KWin Wayland + vkgl 0.1.35。
- 交换链：3 张 image，dmabuf zero-copy；无 FBO/shm fallback。
- 内核：7.3.4 16K PREEMPT_RT，clang-full-LTO 与 gcc-O3 双变体。

## perf 热点（vkmark effect2d，1080p）

| 占比 | 位置 |
|---:|---|
| 32% | `vkgl_AcquireNextImageKHR` 路径内的 WSI/DRM 等待 |
| 18% | `__GI___ioctl` → `drmIoctl` |
| 8% | `clock_gettime` |
| 8% | `glUniform1i` |
| 6.8% | `pthread_mutex_unlock`（`libEGL_gsgpu`） |

这说明提升方向是减少每帧的合成器/提交等待，而不是继续调 `-O3`/LTO 或 shader cache。

## 已测且否决

1. **4ms poll 切片**：`wait_buffer_release()` 原实现每 4ms 醒一次；隔离构建改为无限等待时
   阻塞、有限等待用剩余时间。同负载生产版 32/31/31，测试版 32/32/31，无可复现差异，
   不安装。
2. **swapchain 4 张图**：强制 minImageCount=4，同负载测试版 32/30/31，生产 3 张 32/35/35；无收益且更差，不安装。
3. **present `glFinish` 改 EGL fence**：历史六轮候选均无正收益，保留保守同步。
3. **clear 合并**：仅合并单 color+depth 且两个 clear value 的排列；draw 时间不是主墙钟。
4. **uniform/UBO/UpdateBuffer/vertex/index/scissor**：逐项验证后均未改变 1080p 主瓶颈。
5. **vkgl 0.1.35 swapchain/fence/semaphore**：严格矩阵 13/13、vkgl 官方 5/5 通过，
   但性能仍受 WSI 等待限制。

## 双内核 A/B

同机 ABA（gcc → clang → gcc，1080p FIFO）：

- gcc 中位 Score 36；clang 中位 Score 35；逐场景差 ≤2 FPS。
- 结论：gcc-O3 与 clang-fullLTO 性能持平；差异小于背景负载。
- 原始日志：`gpu/evidence/CLANG-GCC-ABA-734.md`（本地仓库）。

## 下一步实验（按收益/风险排序）

1. **KWin direct scanout / fullscreen 路径**：确认全屏 vkmark 是否走 direct scanout；
   若走，比较与合成路径的 FPS/延迟，定量合成器开销。
2. **swapchain image 数量**：3 张是否足够隐藏 present 等待；测试 2/4 张的 acquire 命中率。
3. **DMA-BUF modifier/lifetime**：与 KWin/vendor GBM 全屏 BO 生命周期对齐，减少重定位。
4. **amdgpu/gsgpu 提交路径**：`drmIoctl` 18% 中区分 BO list、CS submit、fence wait；
   只在能证明是用户态可优化项时动 vkgl。
5. **上游 UABI/原生 Vulkan**：继续跟踪 `lg110-open-gpu`/vendor 新内核；没有 UABI 前
   不伪造原生 RADV。

## 验收门槛

任何 vkgl 改动必须同时满足：

- 同负载连续 3 轮，FPS 中位提升超过运行方差；
- vkgl 官方 5/5、严格矩阵 13/13、0 validation；
- vkcube/KWin 实际画面无撕裂/错帧；
- 失败可一键回滚到已发布 `libvkgl.so`。

## 复现

```bash
# 1080p 三轮，记录内核/负载/ICD
scripts/bench-vkgl-1080p.sh
```

## fullscreen / direct scanout 观察

KWin 报告 compositing active，未显示 direct scanout 状态。vkmark 2 组交替：
windowed Score 31/32，fullscreen Score 27/27（load 约 11 的 Homebrew 背景负载）。
fullscreen 没有可验证的 direct scanout 收益，反而更低；不据此改 KWin/vkgl。

## 去每提交 glFlush（2026-11-14，否决）

在含 scissor-Y 修复的基线上仅移除 `execute_cmds` 末尾 `glFlush()`：
scissor A/B、vkgl 5/5 全过；同负载 vkmark 1080p FIFO 测试 33/33/34，
生产 31/34/33，中位同为 33。无可复现收益，不进入生产。

注：第一次基于旧源构建时 scissor FAIL，生产同测试 PASS，说明旧源缺
scissor 修复；该次“+2 分”不作证据。

## sampler uniform 缓存（2026-11-14，否决）

在含 scissor-Y 修复的基线上，为 `Pipeline` 增加 `(uniform location, unit)`
缓存，跳过重复 `glUniform1i`。功能全过；同负载 vkmark 1080p FIFO
测试 36/35/35，生产 35/35/35，中位相同，无复现收益，不进入生产。

## CPU/合成器占用（2026-11-14）

1080p FIFO vkmark 期间：vkmark 进程 CPU 4–7%，kwin_wayland 0.4%，
Score 35。35 FPS 不是 CPU-bound，也不是 KWin 合成器 CPU-bound；
no-flush、sampler 缓存等 CPU 微优化无收益与此一致。
瓶颈在 WSI/显示/GPU 侧，不再重复“省 GL 调用”类实验。
