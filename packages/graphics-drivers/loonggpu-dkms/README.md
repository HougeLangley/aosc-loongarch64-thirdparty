# loonggpu-dkms 补丁

AOSC 的 `loonggpu-kernel-dkms` 包把厂商源码装到 `/usr/src/loonggpu-1.0.2`，
本目录存放发给它的补丁（不是内核补丁）。

| 补丁 | 作用 |
|---|---|
| `patches/0001-trace-ring-name-as-string.patch` | 把两个 tracepoint 里的 `char *ring_name` 改成 `__string(...)` + `__get_str()`。原写法是裸指针，新内核的 tracepoint 安全校验会在 dmesg 里报警：`event 'loonggpu_sched_run_job' has unsafe pointer field 'ring_name'`。 |

## 本地应用方式

```bash
cd /usr/src/loonggpu-1.0.2
sudo patch -p1 < /path/to/0001-trace-ring-name-as-string.patch
sudo dkms build loonggpu/1.0.2 -k "$(uname -r)" --force
sudo dkms install loonggpu/1.0.2 -k "$(uname -r)" --force
```

> 注意：`dkms install` 只更新 `/lib/modules/<rel>/updates/dkms/loonggpu.ko.zst`，
> 已加载的模块要重启（或卸载后重载）才会换成新版本。

## 另一个 DKMS 前置条件：objtool

内核开启 `CONFIG_OBJTOOL`/ORC 展开时，外部模块构建需要
`/usr/src/linux-headers-<rel>/tools/objtool/objtool`。本仓库的内核 headers
打包脚本已经把它包含进去（`package-kernel-*.sh` 里的 `tools/objtool`）。
缺少时 DKMS 会报 `/bin/sh: .../tools/objtool/objtool: No such file or directory`。
