# Rejected vkgl 0.1.36 fence-failure negative-cache candidate

Date: 2026-11-12

## Decision

**Not merged, installed, or published.** The candidate reduced repeated failing
EGL calls but six serial AB/BA rounds showed no statistically supported FPS
improvement. Production remains vkgl 0.1.35 with library SHA-256
`78c963855189836046520f1ee9f327057bd61d7a75c2b8e40b8988f3ea473668`.

The experiment started from the authoritative 0.1.35 package source in a
separate directory. It did not modify this package, `/usr/lib`, or the stale
historical `infra/vkgl` workspace.

## Patch and functional evidence

The three-line logical change adds `GlCtx::fence_sync_create_failed`, skips
`eglCreateSyncKHR` after its first `EGL_NO_SYNC_KHR`, and retains the existing
`glFinish` fallback. See `vkgl-0.1.36-fence-cache-rejected.diff`.

Candidate library SHA-256:
`414f33852a79149d581ac22f4cccb5405e4db86acacf369939ad1acb6769c4c4`.
An unmodified 0.1.35 rebuild in the candidate directory was byte-identical to
production.

For `vkcube --wsi wayland --c 60`:

| Measurement | Production | Candidate |
| --- | ---: | ---: |
| Real `eglCreateSyncKHR` entries | 61 | 1 |
| Failure debug messages | 61 | 1 |
| dmabuf presents | 60 | 60 |
| zero-copy initialization messages | 6 | 6 |
| Exit status | 0 | 0 |

Both drivers passed the existing dmabuf and wl_shm smoke suites with zero
validation errors and no software renderer. Scissor output was exactly
`0000ffff000000ff` for both; GPU fence readback was exactly `663300ff` for both.
The fence waitAll/reset/reuse/waitAny checks passed. The legacy standalone fence
test's pre-existing one-time-command-buffer resubmission validation message was
identical on both and was not counted as a smoke regression.

## Performance result

Six serial AB/BA rounds used 640x480 FIFO, four seconds per scene, Khronos
validation, and no debug/preload instrumentation. All 12 runs passed hardware,
validation, FPS-presence and exit-status guards.

| Scene | Production median FPS | Candidate median FPS | Median paired change | Pair range | Two-sided sign-test p |
| --- | ---: | ---: | ---: | ---: | ---: |
| vertex | 329.0 | 331.5 | +0.77% | -4.50% to +5.18% | 0.6875 |
| texture | 223.5 | 225.5 | -0.26% | -2.68% to +6.98% | 1.0000 |
| shading | 279.5 | 282.0 | +0.73% | -3.39% to +4.74% | 1.0000 |

All ranges cross zero and the sign tests do not support an improvement. Reduced
logging/call counts are not presented as an FPS gain. The complete candidate,
raw logs, and 89-file verified manifest remain locally under
`/home/houge/infra/gpu/vkgl-0.1.36-fence-cache/`.

A first test-only interposer crashed and caused systemd to save one 1.1 MiB
vkcube dump. The lead verified its PID, timestamp, command and absolute path,
then removed only that test-generated dump. No other coredump was changed; the
system remained `running`. Later instrumentation completed normally.
