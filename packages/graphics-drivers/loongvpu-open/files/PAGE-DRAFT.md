# UNTESTED_ON_LG200

**This is an experimental source-and-binary candidate, not an LG200 hardware-validated release. No LG200 hardware decode, image correctness, performance, or stability test has been performed. The user waived the LG200 validation gate, not the requirement to disclose it.**

Package: `loongvpu-open` version `0.0.0+git20261118.8d952056-6`, architecture `loongarch64`.

- Upstream: `tsuibin/loongvpu-vaapi-loongarch64` at `8d95205627f83f6b36d09a9263ac9f381959c6c3`.
- Patch: approved `capability-truthfulness.diff`; H264 ConstrainedBaseline/Main/High and HEVC Main, VLD only.
- Included entries: `loongvpu_drv_video.so` and `loonggpu_drv_video.so`.
- Exact patched source, recipe, copyright notices and rebuild instructions are inside the deb as `source.tar.xz` and documentation.
- Runtime prerequisites retain versioned `loonggpu-driver`, `loongvpu-kernel-dkms`, `libva`, and glibc dependencies.
- Explicit opt-in only. This page draft does not publish the package or add it to a repository.

## No LS9A equivalence

There is no `ls9a_3b6600_vpu.so` implementation or symlink. This package is not an all-platform equivalent of the official vendor package; 3B6000M/LS9A default selection and functionality are unverified.

## Vendor replacement and EGL JSON risk

The package has `Provides/Conflicts/Replaces: loongvpu`. Explicit replacement may remove vendor files. The official vendor `loongvpu/prerm` executes:

```bash
rm -f /usr/share/glvnd/egl_vendor.d/40_loonggpu.json
```

Back up and restore this EGL vendor JSON where applicable. Do not infer that its absence on one LG110 makes removal safe on another target.

## Validation boundary

Build and isolated tests include `make test`, 78 capability checks, two isolated libva driver-name routes, metadata/ELF/copyright audits, and rebuild from the source archive embedded in the deb. Soft-degrade `vainfo` is not hardware decode evidence.

**UNTESTED_ON_LG200 — independent verifier PASS is required before any deploy.**
