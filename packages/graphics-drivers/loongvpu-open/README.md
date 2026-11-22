# loongvpu-open

`loongvpu-open` is the AOSC third-party recipe for an experimental, source-built LoongVPU VA-API driver. This directory is the monorepo copy of the reviewed REL6 recipe from `/home/houge/infra/pkg/loongvpu-open`.

## Fixed package facts

- Upstream source: <https://github.com/tsuibin/loongvpu-vaapi-loongarch64>
- Fixed commit: `8d95205627f83f6b36d09a9263ac9f381959c6c3`
- Version: `0.0.0+git20261118.8d952056-6`
- Approved patch: `files/capability-truthfulness.diff`, SHA256 `f63846d8188238b73c4ecbed2d3c1614c3c2321aa5e5dfa677a7180dd23f252c`
- Runtime dependencies: `glibc`, versioned `loonggpu-driver`, versioned `loongvpu-kernel-dkms`, and `libva`
- Package relationships: `Provides`, `Conflicts`, and `Replaces: loongvpu`

`CHKUPDATE="none"` is intentional. This is a fixed experimental snapshot, not a moving upstream-release subscription.

## Mandatory support boundary

**UNTESTED_ON_LG200.** Compilation, unit tests, isolated libva loading, and source reproduction do not prove LG200 hardware decoding, picture correctness, performance, or stability. Soft-degrade `vainfo` is not hardware evidence.

There is no `ls9a_3b6600_vpu.so` implementation or symlink. No LS9A/3B6000M support or all-platform vendor equivalence is claimed.

Installing this package is explicit opt-in and can replace vendor files. The official vendor `loongvpu/prerm` removes `/usr/share/glvnd/egl_vendor.d/40_loonggpu.json`; target-system backup and restoration procedures remain mandatory. Do not install or deploy this package as part of recipe validation.

## Package contents

The staged package installs `loongvpu_drv_video.so` and the relative `loonggpu_drv_video.so` symlink, copyright and source-provenance notices, full licensing texts, rebuild instructions, and deterministic `source.tar.xz`. The archive contains the patched source and complete recipe without `.git`, compiled objects, driver binaries, or test binaries.

See [BUILDING.md](BUILDING.md), [REBUILD.md](files/REBUILD.md), [README.AOSC](files/README.AOSC), [SOURCE-AND-LICENSE](files/SOURCE-AND-LICENSE), and [UNTESTED_ON_LG200](files/UNTESTED_ON_LG200). Independent verifier approval and Lead publication are separate gates.
