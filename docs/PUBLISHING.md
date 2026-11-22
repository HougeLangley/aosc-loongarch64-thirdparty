# 发布到第三方源

仓库采用 Debian `dists` 布局：

```
pool/main/<首字母>/<pkg>/<pkg>_<ver>-<rel>_loongarch64.deb
dists/stable/main/binary-loongarch64/Packages(.gz)
dists/stable/Release
dists/stable/InRelease        # gpg 签名
```

## 流程

```bash
./scripts/publish-debs.sh --dry-run build/*.deb   # 演练
./scripts/publish-debs.sh --deploy build/*.deb    # 发布
```

发布器内部顺序（不可打乱）：

1. **pool 收编**：按包名归档、原子落盘（先写临时文件再 rename）。
2. **索引重建**：`Packages` + `Packages.gz`。
3. **签名**：用既有仓库身份生成 `Release`、`InRelease`、`Release.gpg`。
4. **部署**：`pool → Packages → Release/InRelease` 顺序 rsync，尽量让客户端抓到一致索引。
5. **验证**：
   - 本地索引内部一致性（MD5）；
   - 本地与服务器索引 md5 一致；
   - HTTPS 可达且包数一致；
   - 隔离 apt（临时 sources.list）能 `apt-get update`。

## 密钥

仓库签名密钥指纹记录在 `repo/key.gpg` 对应的私钥环境中（`~/.gnupg` 或 `INFRA/gnupg`）。
**私钥不入库**，仓库只发布公钥与 `sources.list` 片段：

```bash
gpg --armor --export <fingerprint> > repo/key.gpg
```

## 撤回与恢复

- 删除 `pool/` 中对应 deb 后重新 `--index-only --deploy` 可从索引中撤回；
- 如需彻底撤回，再同步删除服务器上的 pool 文件（发布器不会自动删除远端文件）；
- latest-only 策略下旧版不备份。恢复旧版必须重新取得或构建并验证对应产物，不能依赖
  本地 attic 或上一版回滚副本。

## 站点上的公钥

发布器会把公钥同步到站点根：

```
https://homebrewloongarch64.site/aosc/key.gpg     # ASCII armored，给 gpg --dearmor 用
https://homebrewloongarch64.site/aosc/thirdparty.gpg  # 二进制 keyring
```

`repo/key.gpg` 是同一份公钥的仓库副本。**改动签名密钥后必须同时更新这三处**，
否则用户按 README 安装时会得到 `NO_PUBKEY`。`srv/aosc/key.gpg` 曾经是 0 字节，
就是这类漂移的实例（2026-11-04 修复）。

## README 最新版清单与 latest-only 保留（强制对账）

根 `README.md` **只列每个包/架构的最新版本**，不罗列所有历史版本。按用户要求，
仓库采用 **latest-only**：只保留最新版，旧版不保留、不备份，不提供 `pool/.attic`
回滚副本。恢复旧版本必须重新取得或构建经过审计的旧产物，不能假设本地仍有备份。

每次新增、升级或撤回 deb 后运行：

```bash
PKGIDX=/home/houge/infra/srv/aosc/dists/stable/main/binary-loongarch64/Packages
POOL=/home/houge/infra/srv/aosc
python3 -B scripts/sync-readme-package-index.py "$PKGIDX" README.md --pool-root "$POOL"
python3 -B scripts/sync-readme-package-index.py "$PKGIDX" README.md --pool-root "$POOL" --check
```

生成器用 `dpkg --compare-versions` 选择最新版；`--pool-root` 核验**索引内全部**
deb 的路径与 SHA-256，`--check` 在 README 版本/哈希漂移时非零退出。生成表格
不要手工编辑。

清理旧版必须先 dry-run 生成带路径、大小和 SHA-256 的计划，确认保留项后才可应用。
虽然脚本默认 `--keep-old=1` 以兼容旧调用，本仓库执行清理时必须**显式传
`--keep-old=0`**：

```bash
python3 -B scripts/prune-old-debs.py "$PKGIDX" --repo "$POOL" \
  --keep-old=0 --prune-attic --plan-out /tmp/deb-retention-plan.json
python3 -B scripts/prune-old-debs.py --repo "$POOL" --apply /tmp/deb-retention-plan.json
scripts/publish-debs.sh --index-only --dry-run
scripts/publish-debs.sh --index-only --deploy
```

应用时会逐项 resolve 到 `pool/main` 或 `pool/.attic`，拒绝越界、符号链接和哈希变化，
并在删除前后验证所有保留项。keep0 计划还要求每个删除项都有同包/架构的保留 latest，
且经 `dpkg --compare-versions` 确认严格旧于 latest，防止误删最新版。禁止用
`rsync --delete` 或通配符代替。索引部署后，远端也只能应用同一份计划；最后重新运行
README `--check`，验证签名索引、隔离 APT、latest 下载链接和远端实际文件数。
