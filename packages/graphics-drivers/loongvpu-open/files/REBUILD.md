# Rebuild the exact REL6 packaged source

`source.tar.xz` contains the patched upstream source, the complete REL6 recipe, downstream licensing documentation, and `SOURCE-MANIFEST.sha256`. The upstream sub tree was exported from fixed commit `8d95205627f83f6b36d09a9263ac9f381959c6c3` and then had only `capability-truthfulness.diff` applied. It contains no `.git` directory and no compiled objects.

Build prerequisites on AOSC OS: `gcc make pkg-config libva-dev libdrm-dev` and their required dependencies. Rebuilding needs no network access.

From the directory containing `source.tar.xz`:

```bash
tar -xJf source.tar.xz
cd loongvpu-open-source
sha256sum -c SOURCE-MANIFEST.sha256
cd upstream
make clean
make -j"$(nproc)"
make test
sha256sum loongvpu_drv_video.so
```

Compare the resulting `loongvpu_drv_video.so` with `/usr/lib/dri/loongvpu_drv_video.so` from the same REL6 deb. An isolated deb extraction can be used instead of installing:

```bash
dpkg-deb -x ../loongvpu-open_0.0.0+git20261118.8d952056-6_loongarch64.deb rel6-root
cmp upstream/loongvpu_drv_video.so rel6-root/usr/lib/dri/loongvpu_drv_video.so
```

`make test` must report `capability_test PASSED (78 checks; H264/HEVC Main VLD only)` and pass the other test groups. On a machine without a VPU render node, the load test's soft-degrade message is expected. No successful LG200 hardware decode is implied: **UNTESTED_ON_LG200**.
