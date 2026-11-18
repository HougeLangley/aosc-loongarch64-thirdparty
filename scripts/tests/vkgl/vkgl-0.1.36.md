# vkgl-loonggpu 0.1.36-1 host Event state correction

Date: 2026-11-18

## Scope and root cause

This release packages the independently reviewed host Event correctness fix.
Version 0.1.35 created Events as stateless `Obj` instances, returned
`VK_EVENT_SET` from every `vkGetEventStatus`, and did not access the Event in
`vkSetEvent`/`vkResetEvent`. New and reset Events therefore incorrectly appeared
signaled.

Version 0.1.36 gives every Event its own `std::atomic<bool> signaled{false}`.
Create starts UNSIGNALLED, Set and Reset update only that object, Get returns the
corresponding `VK_EVENT_SET`/`VK_EVENT_RESET`, and Destroy deletes the exact
`Event` type after unregistering the original handle. No global Event state,
GPU-command format, EGL fence, compute, descriptor, or performance change is
included.

## Public regression test

`vktest-event.c` is a strict C11 test built with `-Wall -Wextra -Werror`. It
requires one explicitly selected vkgl ICD and verifies the full LG110 device
name, vendor/device IDs, and non-CPU type. Two Events cover independent state,
repeated Set/Reset, valid `VkResult`, destruction while signaled, and recreation
after destruction.

The same test binary produced these pre-package results on the real LG110:

| Driver | Runs | Result |
| --- | ---: | --- |
| Installed 0.1.35-1 baseline | 2 | Expected rc=2 and 9 mismatches each |
| Isolated 0.1.36 candidate | 2 | rc=0 and zero mismatches each |

The candidate also passed standalone `vkcube --c 60` with Khronos validation and
both existing dmabuf/wl_shm smoke paths. All three validation counts were zero;
every run enumerated `LoongGPU LG110 (vkgl GLES2)` without software rendering.
The raw evidence is under
`/home/houge/infra/gpu/evidence/lg110-event-fix-20261118/`.

Accepted source SHA-256:
`d629388a7fb74f45edb1d9d3dbdacc5f3edd01ad4b0fdc62dfbf2b1adde18cc2`.
Accepted test source SHA-256:
`2b13b27102ad558d659cc02305c1f5b7524748ef70b6253a4ff447d4e66ba030`.
Accepted candidate library SHA-256:
`728b6741855da6ba2149eeb98ec62481a3b56271d1fe603d0dd9ed612e3ece36`.

## Package, installation, and publication

The recipe is `VER=0.1.36`, `REL=1`. The built package is
`vkgl-loonggpu_0.1.36-1_loongarch64.deb`, SHA-256
`5be2c7e59e9559b3f61af32e6171d232356afbce3787f53552526da558c98002`.
Its control metadata and payload were checked with `dpkg-deb`; the packaged and
installed library is byte-identical to the accepted candidate above. The payload
contains only the vkgl library and system ICD, plus the existing `postinst`
control script.

`publish-debs.sh --dry-run` passed without changing repository bytes. Local
`dpkg -i` then installed `vkgl-loonggpu 0.1.36-1 loongarch64`; `dpkg-query`
confirmed the version and architecture. Using only
`/usr/share/vulkan/icd.d/vkgl_loonggpu.json`, the installed Event test returned
`event_semantics=PASS mismatches=0`, and `vkcube --c 60` returned zero with zero
validation errors while selecting the real LG110.

`publish-debs.sh --deploy` completed all pool, Packages/Release, InRelease
signing, server synchronization, HTTPS, and isolated apt checks with 97 packages.
Independent SHA-256 comparisons matched for the local, server, and HTTPS deb,
Packages, and InRelease artifacts. Public InRelease signature verification also
passed. Isolated apt policy selects `0.1.36-1` and still lists `0.1.35-2` from
the public HTTPS repository.

The public rollback package remains
`vkgl-loonggpu_0.1.35-2_loongarch64.deb`, SHA-256
`9130cfa2582c5bac438c313b100b3f352e7bce421079c404d63812ada03bbb25`;
its HTTPS bytes match the local and server copies. The previously installed
0.1.35-1 package is additionally preserved in the external evidence directory.

Complete package and publication evidence, including raw commands and outputs,
is under
`/home/houge/infra/gpu/evidence/lg110-event-fix-20261118/package-0.1.36/`.
The source commit and pushed remote hash are recorded there after the Git
operation. No performance improvement is claimed, and no desktop restart was
performed.
