# Building and verifying brew-ui-linux

These procedures use the self-contained source in `files/` and stage files under a build directory. They do not install the deb or publish it.

## Prerequisites

The explicit build dependencies declared in `autobuild/defines` are `gcc-runtime qt-6`; the AOSC BuildKit already supplies CMake, the compiler, and Make. Runtime dependencies remain exactly `qt-6 glibc gcc-runtime`, matching the published 0.1.0-5 package metadata.

Syntax-check the recipe from the monorepo root:

```bash
bash -n packages/app-utils/brew-ui-linux/autobuild/build
```

## Lightweight monorepo package build

```bash
ROOT="$(git rev-parse --show-toplevel)"
PKG="$ROOT/packages/app-utils/brew-ui-linux"
OUT="$ROOT/build" KEEP_STAGE=1 \
  "$ROOT/scripts/build-package.sh" "$PKG"
```

`DUMMYSRC=1` gives the recipe an empty source work directory; `autobuild/build` copies the authoritative `files/` tree into it. The recipe then runs the same CMake sequence recorded by the existing 0.1.0-5 build:

```bash
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTING=ON \
  -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build -j"$(nproc)"
ctest --test-dir build --output-on-failure
DESTDIR="$PKGDIR" cmake --install build
```

The expected CTest tests are `backend_json` and `gui_smoke`. `gui_smoke` uses `QT_QPA_PLATFORM=offscreen`, constructs the full window, and exits without running Homebrew.

The recipe also installs `README.md` and `LICENSE` under `/usr/share/doc/brew-ui-linux`, checks the staged executable and desktop file, verifies `--version`, and runs the staged `--smoke-test` offscreen. It never invokes a Homebrew mutation.

## Re-run existing CTest without rebuilding

When a completed source build already exists, its tests can be rechecked without recompiling:

```bash
ctest --test-dir build/src/brew-ui-linux/build --output-on-failure
build/src/brew-ui-linux/build/brew-ui-linux --version
QT_QPA_PLATFORM=offscreen \
  build/src/brew-ui-linux/build/brew-ui-linux --smoke-test
```

This validates the existing binaries, not a newly built candidate deb. Keep that distinction in the evidence report.

## Optional real, read-only Homebrew checks

The application supports explicit read-only integration checks when a known Homebrew executable is available:

```bash
QT_QPA_PLATFORM=offscreen brew-ui-linux \
  --brew /absolute/path/to/brew --check-inventory
```

`--check-inventory` performs one inventory query and exits 0 only after a valid response. `--check-management` performs read-only formula, service, and tap queries. Neither mode installs, removes, starts, or stops anything. Do not substitute a successful GUI smoke test for these integration checks, and do not run either mode as part of an unattended package build.

No `dpkg -i`, repository publication, or system configuration change is required for recipe validation.
