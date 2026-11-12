#include <QGuiApplication>
#include <QOpenGLContext>
#include <QOpenGLFunctions>
#include <QSurfaceFormat>
#include <QTimer>
#include <QWindow>
#include <QDebug>
#include <EGL/egl.h>
#include <cstdio>
#include <cstring>
#include <sys/prctl.h>

static QString formatDescription(const QSurfaceFormat &f)
{
    return QStringLiteral(
        "renderableType=%1 version=%2.%3 profile=%4 "
        "RGBA=%5,%6,%7,%8 depth=%9 stencil=%10 samples=%11 swapBehavior=%12 swapInterval=%13")
        .arg(f.renderableType())
        .arg(f.majorVersion()).arg(f.minorVersion()).arg(f.profile())
        .arg(f.redBufferSize()).arg(f.greenBufferSize()).arg(f.blueBufferSize()).arg(f.alphaBufferSize())
        .arg(f.depthBufferSize()).arg(f.stencilBufferSize()).arg(f.samples())
        .arg(f.swapBehavior()).arg(f.swapInterval());
}

int main(int argc, char **argv)
{
    bool renameForProductionShim = false;
    bool offscreen = false;
    bool allowSurfaceless = false;
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--plasma-name") == 0)
            renameForProductionShim = true;
        else if (std::strcmp(argv[i], "--offscreen") == 0)
            offscreen = true;
        else if (std::strcmp(argv[i], "--allow-surfaceless") == 0)
            allowSurfaceless = true;
    }

    // Match the production shim's process-name gate without touching plasmashell.
    if (renameForProductionShim && prctl(PR_SET_NAME, "plasmashell", 0, 0, 0) != 0) {
        qFatal("PR_SET_NAME(plasmashell) failed");
    }

    qputenv("QT_LOGGING_RULES", "qt.qpa.*=true\nqt.opengl.*=true");
    QGuiApplication app(argc, argv);
    qInfo().noquote() << "TEST begin pid=" << app.applicationPid()
                      << "platform=" << app.platformName()
                      << "qt=" << qVersion()
                      << "mode=" << (offscreen ? "offscreen" : "window")
                      << "plasmaName=" << renameForProductionShim;

    QSurfaceFormat format; // Deliberately use Qt's default, as Plasma does unless overridden.
    format.setSwapInterval(0); // Exercise the non-blocking swap path.
    fprintf(stderr, "TEST platform=%s qt=%s requested={%s}\n",
            qPrintable(app.platformName()), qVersion(), qPrintable(formatDescription(format)));
    qInfo().noquote() << "TEST default format:" << formatDescription(QSurfaceFormat::defaultFormat());

    QWindow window;
    window.setSurfaceType(QSurface::OpenGLSurface);
    window.setFormat(format);
    window.resize(128, 128);
    if (!offscreen) {
        window.create();
        window.show();
        app.processEvents();
        qInfo() << "TEST QWindow created handle=" << window.handle();
    }

    QOpenGLContext context;
    context.setFormat(format);
    if (!context.create()) {
        qCritical() << "TEST QOpenGLContext::create FAILED";
        return 20;
    }
    qInfo().noquote() << "TEST context created actual format:" << formatDescription(context.format())
                      << "valid=" << context.isValid() << "share=" << context.shareContext();

    bool madeCurrent = false;
    if (offscreen) {
        // Still create a hidden native window surface: this test intentionally targets WINDOW.
        madeCurrent = context.makeCurrent(&window);
    } else {
        madeCurrent = context.makeCurrent(&window);
    }
    if (!madeCurrent) {
        qCritical() << "TEST makeCurrent FAILED";
        return 21;
    }
    qInfo() << "TEST makeCurrent OK";

    QOpenGLFunctions *gl = context.functions();
    EGLDisplay eglDisplay = eglGetCurrentDisplay();
    EGLSurface drawSurface = eglGetCurrentSurface(EGL_DRAW);
    const GLubyte *glVendor = gl->glGetString(GL_VENDOR);
    const GLubyte *glRenderer = gl->glGetString(GL_RENDERER);
    const GLubyte *glVersion = gl->glGetString(GL_VERSION);
    const char *eglVendor = eglDisplay != EGL_NO_DISPLAY ? eglQueryString(eglDisplay, EGL_VENDOR) : nullptr;
    const char *eglVersion = eglDisplay != EGL_NO_DISPLAY ? eglQueryString(eglDisplay, EGL_VERSION) : nullptr;
    fprintf(stderr, "TEST current display=%p draw_surface=%p EGL_VENDOR=%s EGL_VERSION=%s GL_VENDOR=%s GL_RENDERER=%s GL_VERSION=%s\n",
            eglDisplay, drawSurface,
            eglVendor ? eglVendor : "(null)", eglVersion ? eglVersion : "(null)",
            glVendor ? (const char *)glVendor : "(null)",
            glRenderer ? (const char *)glRenderer : "(null)",
            glVersion ? (const char *)glVersion : "(null)");
    if (drawSurface == EGL_NO_SURFACE) {
        fprintf(stderr, "TEST FAIL: Qt returned surfaceless success for a QWindow; no EGL draw surface\n");
        if (!allowSurfaceless)
            return 22;
        fprintf(stderr, "TEST continuing only to capture the failing interval/swap EGL errors\n");
    }

    gl->glClearColor(0.05f, 0.20f, 0.10f, 1.0f);
    gl->glClear(GL_COLOR_BUFFER_BIT);
    context.swapBuffers(&window);
    qInfo() << "TEST swapBuffers returned";
    context.doneCurrent();
    if (!offscreen)
        window.hide();
    if (drawSurface == EGL_NO_SURFACE)
        return 23;
    qInfo() << "TEST PASS";
    fprintf(stderr, "TEST PASS native window context and swap completed\n");
    return 0;
}
