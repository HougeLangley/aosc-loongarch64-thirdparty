# Homebrew Manager for Linux

An **unofficial** native Qt 6 frontend for Homebrew on Linux, created for AOSC
OS/LoongArch64. It is not the macOS `Homebrew/BrewUI` binary and does not claim
SwiftUI compatibility. The official project's architecture and transparency
requirements informed this implementation; no macOS application source is
copied here.

## Implemented scope

- Reads `brew info --json=v2 --installed` and tolerates unknown JSON fields.
- Shows installed name/version/outdated state/description.
- Installs one exact formula name; uninstalls or upgrades the selected formula.
- Runs explicit `brew update` or confirmed `brew upgrade`.
- Reads `brew services list --json`; starts, stops or restarts a selected service
  after confirmation through Linux `systemctl` (Homebrew's own backend).
- Lists taps, adds an exact `user/repository` tap, or removes the selected tap
  after confirmation.
- Executes literal argv through `QProcess`, never a shell command string.
- Serialises commands, shows a copyable command and complete stdout/stderr.
- Disables competing mutations while a command runs and cancels its process
  group on request.
- Does not invoke `autoremove`, silently hide errors, or bundle Homebrew itself.

## Build and test

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
cmake --build build -j2
ctest --test-dir build --output-on-failure
```

`gui_smoke` uses `QT_QPA_PLATFORM=offscreen` and constructs the full window
without launching Homebrew. Runtime uses `$HOMEBREW_BREW_FILE`, `PATH`, standard
Linux prefixes, or `--brew /absolute/path/to/brew`. It sets
`HOMEBREW_NO_INSTALL_FROM_API=1` because upstream does not publish a LoongArch
package API; local taps remain authoritative. `HOMEBREW_NO_AUTO_UPDATE=1` is set
for every operation except the explicit Update taps action. Homebrew remains
separately installed and authoritative. Formulae, Linux systemd services and tap
management are implemented; macOS casks and authentication helpers are not
emulated on Linux.

For a real, read-only end-to-end check (including QProcess, Homebrew 7.x, JSON
parsing and table population), run:

```sh
QT_QPA_PLATFORM=offscreen brew-ui-linux \
  --brew /home/houge/infra/brew-build/bin/brew --check-inventory
```

It exits 0 only after a valid inventory response, 1 on command/parse failure and
124 after a 60-second timeout; it never installs or removes packages.
`--check-management` instead chains the real formula, service and tap queries,
requiring all three tables to parse before returning 0 (90-second timeout).
Neither check starts, stops, installs or removes anything.

Upstream reference: <https://github.com/Homebrew/BrewUI>. This independent
frontend is distributed under AGPL-3.0-or-later to remain license-compatible
with the official project.
