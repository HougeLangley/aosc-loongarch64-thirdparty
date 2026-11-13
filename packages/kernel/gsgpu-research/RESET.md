# LG110 / CHIP_LG100 reset 原语核查

日期：2026-11-13  
范围：只读源码和 PCI 配置空间核查；没有写寄存器、解绑定、加载模块或触发 reset。

## 结论

**当前没有可验证的 LG110 硬件 reset 原语，继续 fail-closed 是正确的。phase4 的 scheduler 生命周期修复不构成硬件恢复能力。**

## 1. 本机 PCI ID 在生产驱动中的真实分类

生产 `loonggpu 1.0.2` 的 PCI 表把：

- `0014:7a25` 映射为 `CHIP_LG100`，即本机 `00:06.0`；
- `0014:7a35` 才映射为 `CHIP_LG200`。

`loonggpu_common.c` 只在 `CHIP_LG200` 上发送
`LG2XX_ICMD32(MOP_GPIPE, SOP_GPIPE_RESET)`。CHIP_LG100 和第三方 gsgpu 的公共 reset
随后都直接 `return 0`，没有任何硬件操作。

不能把 LG200 的 GPIPE_RESET 命令复制给 LG110/CHIP_LG100；当前没有命令兼容性或完成状态证据。

## 2. 被绕过的 PCI config reset 不是已验证备用方案

gsgpu 与生产 loonggpu 都保留一个不可达函数，其操作为：

1. `pci_clear_master()`；
2. 向 PCI 配置偏移 `0x7c` 写入 magic `0x39d5e86b`；
3. 延时100微秒；
4. 在循环中用恒真的 `if (1)` 立即成功、恢复 bus master 并设置 `has_hw_reset=true`。

源码注释仍写着“Only applicable to asics prior to vega10”，没有 LG110 的寄存器说明。
该函数没有检查写回值、reset 完成位、引擎状态或恢复后的 ring/VM/VRAM 一致性。

本机只读结果：

- `lspci -xxxx -s 00:06.0` 只列出前64字节；
- 通过 sysfs 在 `0x40/0x60/0x70/0x7c` 的扩展读取均返回 EOF；
- `setpci -s 00:06.0 0x7c.l` 读回 `0xffffffff`。

这些结果至少说明当前系统没有观察到已实现的 `0x7c` reset 寄存器；结合调用方显式绕过及恒真完成检测，
绝不能仅删除提前 `return 0` 就把它当成可用 reset。

## 3. 生产驱动也没有 LG100 reset 证明

生产 `loonggpu_reset()` 对 CHIP_LG100 同样直接返回成功，PCI config 调用位于该 return 之后。
因此生产驱动能正常运行桌面不等于它具备 hang 后硬件恢复能力，也不能作为启用 gsgpu reset 的依据。

## 放行前所需证据

1. 对应 LG110/CHIP_LG100 的厂商 reset 序列或经独立验证的等价机制；
2. 可观测的完成/失败状态、超时和有界等待，禁止恒真成功；
3. reset 前后 bus-master、中断、ring、VM、VRAM/shadow 与 DC 的一致性设计；
4. 独立可恢复测试机、生产驱动冲突隔离和可靠回退路径；
5. 最后才是受控 timeout/reset 测试。任何 compile/MODPOST PASS 都不替代上述证据。
