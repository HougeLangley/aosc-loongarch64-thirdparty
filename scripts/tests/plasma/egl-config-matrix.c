#define _GNU_SOURCE
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>

static const char *surface_mask(EGLint v, char out[64])
{
    snprintf(out, 64, "%s%s%s%s", (v & EGL_WINDOW_BIT) ? "WINDOW|" : "",
             (v & EGL_PIXMAP_BIT) ? "PIXMAP|" : "",
             (v & EGL_PBUFFER_BIT) ? "PBUFFER|" : "",
             (v & ~(EGL_WINDOW_BIT | EGL_PIXMAP_BIT | EGL_PBUFFER_BIT)) ? "UNKNOWN" : "");
    return out;
}

static const char *renderable_mask(EGLint v, char out[96])
{
    snprintf(out, 96, "%s%s%s%s%s%s",
             (v & EGL_OPENGL_ES_BIT) ? "ES1|" : "",
             (v & EGL_OPENVG_BIT) ? "OPENVG|" : "",
             (v & EGL_OPENGL_ES2_BIT) ? "ES2|" : "",
             (v & EGL_OPENGL_BIT) ? "OPENGL|" : "",
             (v & EGL_OPENGL_ES3_BIT) ? "ES3|" : "",
             (v & ~(EGL_OPENGL_ES_BIT | EGL_OPENVG_BIT | EGL_OPENGL_ES2_BIT |
                    EGL_OPENGL_BIT | EGL_OPENGL_ES3_BIT)) ? "UNKNOWN" : "");
    return out;
}

static int config_attrib(EGLDisplay d, EGLConfig c, EGLint a)
{
    EGLint v = -999;
    if (!eglGetConfigAttrib(d, c, a, &v))
        fprintf(stderr, "eglGetConfigAttrib config=%p attribute=0x%x failed error=0x%x\n",
                (void *)c, a, eglGetError());
    return v;
}

static void choose(EGLDisplay d, const char *name, const EGLint *a)
{
    while (eglGetError() != EGL_SUCCESS) {}
    EGLint n = -777;
    EGLBoolean ok = eglChooseConfig(d, a, NULL, 0, &n);
    EGLint err = eglGetError();
    printf("MATCH name=%s ret=%d num_config=%d error=0x%x attribs=", name, ok, n, err);
    for (int i = 0; a && a[i] != EGL_NONE; i += 2)
        printf("0x%x=%d(0x%x) ", a[i], a[i + 1], a[i + 1]);
    printf("\n");
}

int main(void)
{
    printf("CONSTANTS WINDOW=%d PIXMAP=%d PBUFFER=%d ES1=%d ES2=%d OPENGL=%d ES3=%d\n",
           EGL_WINDOW_BIT, EGL_PIXMAP_BIT, EGL_PBUFFER_BIT,
           EGL_OPENGL_ES_BIT, EGL_OPENGL_ES2_BIT, EGL_OPENGL_BIT, EGL_OPENGL_ES3_BIT);
    struct wl_display *wd = wl_display_connect(NULL);
    if (!wd) {
        fprintf(stderr, "wl_display_connect failed\n");
        return 2;
    }
    PFNEGLGETPLATFORMDISPLAYEXTPROC getPlatformDisplay =
        (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress("eglGetPlatformDisplayEXT");
    if (!getPlatformDisplay) {
        fprintf(stderr, "eglGetPlatformDisplayEXT unavailable\n");
        return 3;
    }
    EGLDisplay d = getPlatformDisplay(EGL_PLATFORM_WAYLAND_EXT, wd, NULL);
    if (d == EGL_NO_DISPLAY) {
        fprintf(stderr, "eglGetPlatformDisplayEXT failed error=0x%x\n", eglGetError());
        return 4;
    }
    EGLint major = 0, minor = 0;
    if (!eglInitialize(d, &major, &minor)) {
        fprintf(stderr, "eglInitialize failed error=0x%x\n", eglGetError());
        return 5;
    }
    printf("DISPLAY handle=%p EGL=%d.%d VENDOR=%s VERSION=%s CLIENT_APIS=%s\n",
           (void *)d, major, minor, eglQueryString(d, EGL_VENDOR),
           eglQueryString(d, EGL_VERSION), eglQueryString(d, EGL_CLIENT_APIS));

    const EGLint full_window[] = {
        EGL_RED_SIZE, 0, EGL_GREEN_SIZE, 0, EGL_BLUE_SIZE, 0, EGL_ALPHA_SIZE, 8,
        EGL_SAMPLES, 0, EGL_SAMPLE_BUFFERS, 0, EGL_DEPTH_SIZE, 0, EGL_STENCIL_SIZE, 0,
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT, EGL_NONE
    };
    EGLint full_pbuffer[sizeof(full_window) / sizeof(full_window[0])];
    memcpy(full_pbuffer, full_window, sizeof(full_window));
    for (int i = 0; full_pbuffer[i] != EGL_NONE; i += 2)
        if (full_pbuffer[i] == EGL_SURFACE_TYPE)
            full_pbuffer[i + 1] = EGL_PBUFFER_BIT;
    const EGLint window_gl[] = {EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT, EGL_NONE};
    const EGLint pbuffer_gl[] = {EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT, EGL_NONE};
    const EGLint window_es2[] = {EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_NONE};
    const EGLint pbuffer_es2[] = {EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_NONE};
    const EGLint window_only[] = {EGL_SURFACE_TYPE, EGL_WINDOW_BIT, EGL_NONE};
    const EGLint pbuffer_only[] = {EGL_SURFACE_TYPE, EGL_PBUFFER_BIT, EGL_NONE};
    const EGLint both_gl[] = {EGL_SURFACE_TYPE, EGL_WINDOW_BIT | EGL_PBUFFER_BIT,
                              EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT, EGL_NONE};
    const EGLint pixmap_only[] = {EGL_SURFACE_TYPE, EGL_PIXMAP_BIT, EGL_NONE};
    choose(d, "Qt_full_WINDOW_OPENGL", full_window);
    choose(d, "Qt_full_PBUFFER_OPENGL", full_pbuffer);
    choose(d, "WINDOW_OPENGL", window_gl);
    choose(d, "PBUFFER_OPENGL", pbuffer_gl);
    choose(d, "WINDOW_ES2", window_es2);
    choose(d, "PBUFFER_ES2", pbuffer_es2);
    choose(d, "WINDOW_only", window_only);
    choose(d, "PBUFFER_only", pbuffer_only);
    choose(d, "WINDOW_or_PBUFFER_OPENGL", both_gl);
    choose(d, "PIXMAP_only", pixmap_only);

    EGLint count = 0;
    if (!eglGetConfigs(d, NULL, 0, &count) || count <= 0) {
        fprintf(stderr, "eglGetConfigs count failed count=%d error=0x%x\n", count, eglGetError());
        return 6;
    }
    EGLConfig *configs = calloc((size_t)count, sizeof(*configs));
    EGLint got = 0;
    if (!configs || !eglGetConfigs(d, configs, count, &got)) {
        fprintf(stderr, "eglGetConfigs list failed error=0x%x\n", eglGetError());
        return 7;
    }
    printf("CONFIG_COUNT requested=%d returned=%d\n", count, got);
    for (int i = 0; i < got; ++i) {
        EGLConfig c = configs[i];
        EGLint surface = config_attrib(d, c, EGL_SURFACE_TYPE);
        EGLint renderable = config_attrib(d, c, EGL_RENDERABLE_TYPE);
        char sm[64], rm[96];
        printf("CONFIG index=%d handle=%p id=%d surface=%d(0x%x)[%s] renderable=%d(0x%x)[%s] conformant=%d "
               "RGBA=%d,%d,%d,%d depth=%d stencil=%d samples=%d sample_buffers=%d native_visual=0x%x caveat=%d "
               "matchQtWindow=%d matchQtPbuffer=%d\n",
               i, (void *)c, config_attrib(d, c, EGL_CONFIG_ID), surface, surface, surface_mask(surface, sm),
               renderable, renderable, renderable_mask(renderable, rm), config_attrib(d, c, EGL_CONFORMANT),
               config_attrib(d, c, EGL_RED_SIZE), config_attrib(d, c, EGL_GREEN_SIZE),
               config_attrib(d, c, EGL_BLUE_SIZE), config_attrib(d, c, EGL_ALPHA_SIZE),
               config_attrib(d, c, EGL_DEPTH_SIZE), config_attrib(d, c, EGL_STENCIL_SIZE),
               config_attrib(d, c, EGL_SAMPLES), config_attrib(d, c, EGL_SAMPLE_BUFFERS),
               config_attrib(d, c, EGL_NATIVE_VISUAL_ID), config_attrib(d, c, EGL_CONFIG_CAVEAT),
               !!((surface & EGL_WINDOW_BIT) && (renderable & EGL_OPENGL_BIT)),
               !!((surface & EGL_PBUFFER_BIT) && (renderable & EGL_OPENGL_BIT)));
    }
    free(configs);
    eglTerminate(d);
    wl_display_disconnect(wd);
    return 0;
}
