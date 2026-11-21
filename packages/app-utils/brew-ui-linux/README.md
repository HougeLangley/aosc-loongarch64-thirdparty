# brew-ui-linux

`brew-ui-linux` 0.1.0-5 is an unofficial native Qt 6 frontend for Homebrew on Linux. It was created for AOSC OS/LoongArch64; it is not the macOS `Homebrew/BrewUI` binary and does not claim SwiftUI compatibility.

## Source and package authority

The authoritative source for this recipe is the reviewed, self-contained tree under `files/`. It was imported byte-for-byte from the existing build source at `build/src/brew-ui-linux`, excluding its generated `build/` directory. The old source directory is inside the monorepo Git work tree but has no independently tracked upstream repository or release tag.

<https://github.com/Homebrew/BrewUI> is an architectural reference only, not a fabricated download upstream for this independent implementation. The downstream project homepage is the monorepo homepage declared in `autobuild/defines`. The implementation is distributed under AGPL-3.0-or-later; see `files/LICENSE`.

Published 0.1.0-5 metadata is preserved:

- Section: `admin`
- Runtime dependencies: `qt-6 glibc gcc-runtime`
- Description: `Unofficial native Qt Homebrew package manager for Linux`
- Architecture: `loongarch64`

Homebrew is separately installed and authoritative; this package does not bundle it. Commands use literal argv through `QProcess`, not shell command strings. Formula, service, and tap mutations require explicit user actions in the application.

## Update policy

`CHKUPDATE="none"` and `DUMMYSRC=1` are intentional: no separately versioned upstream release endpoint exists. The build script explicitly copies the authoritative `files/` tree into the empty source work directory. Updates are manual and require importing reviewed source changes, rerunning CTest and staging smoke tests, and recording source hashes.

If the application version changes, align `VER`, `project(... VERSION ...)` in `files/CMakeLists.txt`, and the version returned by `files/src/main.cpp`; reset `REL` according to repository policy. For packaging-only changes, retain `VER=0.1.0` and increment `REL`. Never invent an upstream tag or checksum to enable automatic update checks.

See [BUILDING.md](BUILDING.md) for non-installing build, CTest, and smoke-test procedures.
