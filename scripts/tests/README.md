# vkgl 回归测试

| 测试 | 覆盖 |
|---|---|
| `vkfill-test.c` | `vkCmdFillBuffer`：创建 host-visible buffer，命令缓冲区填充 `0xDEADBEEF`，提交后 map 校验 |
| `vkexec-test.c` | `vkCmdExecuteCommands` + 二级命令缓冲区：填充录制在 secondary 里，由 primary 执行，再校验 |

```bash
gcc -O2 -o vkfill-test vkfill-test.c -lvulkan && ./vkfill-test
gcc -O2 -o vkexec-test vkexec-test.c -lvulkan && ./vkexec-test
# 期望输出: fill verification: OK (first mismatch word 0)
```

两个测试都不需要窗口系统（无 surface），可在无桌面环境时运行。
