# Building and verifying loongvpu-open

All commands below build or extract into staging directories. They do not require installing the package or changing the system driver stack.

## Prerequisites

AOSC OS LoongArch64 build dependencies are declared in `autobuild/defines`: `gcc git make libva-dev libdrm-dev pkg-config`. Runtime prerequisites remain the versioned `glibc`, `loonggpu-driver`, `loongvpu-kernel-dkms`, and `libva` requirements.

From the monorepo root:

```bash
PKG=packages/graphics-drivers/loongvpu-open
bash -n "$PKG/autobuild/build"
```

For an offline/reviewed rebuild, set `LOONGVPU_OPEN_SOURCE_REPO` to a verified clone whose `HEAD` can be checked out at the fixed commit. Otherwise the build clones the declared upstream URL. In either case the script checks the exact commit and patch SHA256 before compiling.

## Lightweight monorepo build

```bash
ROOT="$(git rev-parse --show-toplevel)"
PKG="$ROOT/packages/graphics-drivers/loongvpu-open"
OUT="$ROOT/build" KEEP_STAGE=1 \
  "$ROOT/scripts/build-package.sh" "$PKG"
```

The builder creates:

```text
build/loongvpu-open_0.0.0+git20261118.8d952056-6_loongarch64.deb
```

The recipe runs `make test` before staging. A full Ciel/ACBS build remains the preferred release-quality environment; the lightweight builder is the repository's validated `ABTYPE=self`, LoongArch64, no-EPOCH path. Neither path authorizes publication.

## Package and source verification

Set `DEB` to the actual artifact and use a new extraction directory:

```bash
DEB="$ROOT/build/loongvpu-open_0.0.0+git20261118.8d952056-6_loongarch64.deb"
VERIFY="$ROOT/build/verify/loongvpu-open-rel6"
mkdir -p "$VERIFY/root"
dpkg-deb -I "$DEB"
dpkg-deb -c "$DEB"
dpkg-deb -x "$DEB" "$VERIFY/root"
readelf -d "$VERIFY/root/usr/lib/dri/loongvpu_drv_video.so"
```

Expected control facts include Version `0.0.0+git20261118.8d952056-6`, the declared dependencies, and `Provides/Conflicts/Replaces: loongvpu`. ELF `NEEDED` must remain limited to the reviewed runtime libraries. `PAGE-DRAFT.md` and control must carry the same version.

Extract and validate the source embedded in the deb, then rebuild without installing it:

```bash
tar -xJf "$VERIFY/root/usr/share/doc/loongvpu-open/source.tar.xz" -C "$VERIFY"
cd "$VERIFY/loongvpu-open-source"
sha256sum -c SOURCE-MANIFEST.sha256
cd upstream
make -j"$(nproc)"
make test
cmp loongvpu_drv_video.so "$VERIFY/root/usr/lib/dri/loongvpu_drv_video.so"
```

`capability_test` must report all 78 checks and only the reviewed H.264/HEVC Main VLD capability set. The final `cmp` must exit 0.

## Isolated libva smoke tests

Use only the extracted driver directory:

```bash
DRIVERS="$VERIFY/root/usr/lib/dri"
LIBVA_DRIVERS_PATH="$DRIVERS" LIBVA_DRIVER_NAME=loongvpu vainfo
LIBVA_DRIVERS_PATH="$DRIVERS" LIBVA_DRIVER_NAME=loonggpu vainfo
```

Both routes must select the staged driver and expose only the reviewed four VLD-only profiles. No render node on the packaging host means no LG200 hardware test was performed. Record that limitation verbatim in any release evidence.

Do not run package installation, vendor replacement, repository publication, or ICD changes as part of these checks.
