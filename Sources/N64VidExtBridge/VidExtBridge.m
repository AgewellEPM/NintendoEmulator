#import "VidExtBridge.h"
#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <OpenGL/OpenGL.h>

static NSWindow *sWindow = nil;
static NSOpenGLView *sGLView = nil;
static void *sFrameBuffer = NULL;
static int sFBWidth = 0;
static int sFBHeight = 0;
static int sFBStride = 0;
static CGLContextObj sCGL = NULL; // GL context used by the plugin thread
// Forward declaration
static void CaptureFrame(void);

static m64p_error VE_Init(void) {
    if (sWindow) return 0;
    __block m64p_error rc = 0;
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"[VidExt] Init window/context");
        NSOpenGLPixelFormatAttribute attrs[] = {
            NSOpenGLPFADoubleBuffer,
            NSOpenGLPFAColorSize, 24,
            NSOpenGLPFADepthSize, 16,
            0
        };
        NSOpenGLPixelFormat *fmt = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
        if (!fmt) { rc = -1; return; }
        NSRect rect = NSMakeRect(0, 0, 640, 480);
        sGLView = [[NSOpenGLView alloc] initWithFrame:rect pixelFormat:fmt];
        if (!sGLView) { rc = -2; return; }
        sWindow = [[NSWindow alloc] initWithContentRect:rect
                                              styleMask:(NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
        if (!sWindow) { rc = -3; return; }
        [sWindow setTitle:@"Nintendo Emulator - N64 Video"]; 
        [sWindow setContentView:sGLView];
        [sWindow makeKeyAndOrderFront:nil];
        // Cache CGL context pointer for cross-thread use
        sCGL = [[sGLView openGLContext] CGLContextObj];
    });
    return rc;
}

static m64p_error VE_Quit(void) {
    // Clear current context on this thread
    CGLSetCurrentContext(NULL);
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (sWindow) {
            [sWindow orderOut:nil];
            sWindow = nil;
        }
        sGLView = nil;
        sCGL = NULL;
    });
    return 0;
}

static m64p_error VE_ListFullscreenModes(void* sizes, int* num) {
    if (num) *num = 0;
    return 0;
}

static m64p_error VE_SetVideoMode(int width, int height, int bpp, m64p_video_mode mode, int flags) {
    if (!sWindow) VE_Init();
    // Ensure window size on main and cache CGL context pointer
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"[VidExt] SetVideoMode %dx%d (bpp=%d)", width, height, bpp);
        NSRect rect = NSMakeRect(0, 0, width, height);
        [sWindow setContentSize:rect.size];
        sCGL = [[sGLView openGLContext] CGLContextObj];
    });
    // Make the GL context current on the calling (plugin) thread
    if (sCGL) {
        CGLSetCurrentContext(sCGL);
    }
    return 0;
}

static m64p_error VE_ResizeWindow(int width, int height) {
    return VE_SetVideoMode(width, height, 32, M64VIDEO_WINDOWED, 0);
}

static m64p_error VE_SetCaption(const char* c) {
    if (!c) return 0;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (sWindow) {
            [sWindow setTitle:[NSString stringWithUTF8String:c]];
        }
    });
    return 0;
}

static m64p_function VE_GL_GetProcAddress(const char* proc) {
    if (!proc) return NULL;
    // Try OpenGL framework bundle first
    CFBundleRef glBundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
    if (glBundle) {
        CFStringRef name = CFStringCreateWithCString(NULL, proc, kCFStringEncodingASCII);
        if (name) {
            void* fp = CFBundleGetFunctionPointerForName(glBundle, name);
            CFRelease(name);
            if (fp) return fp;
        }
    }
    // Fallback to dlsym
    return dlsym(RTLD_DEFAULT, proc);
}

static m64p_error VE_GL_SetAttribute(m64p_GLattr attr, int value) { return 0; }
static m64p_error VE_GL_GetAttribute(m64p_GLattr attr, int* value) { if (value) *value = 0; return 0; }
static m64p_error VE_GL_SwapBuffers(void) {
    // Ensure the plugin thread has the GL context current
    if (sCGL) {
        CGLSetCurrentContext(sCGL);
        // Flush drawable synchronously on this thread
        CGLFlushDrawable(sCGL);
        // Capture after swap (synchronous)
        CaptureFrame();
        if (sFBWidth > 0 && sFBHeight > 0) {
            NSLog(@"[VidExt] SwapBuffers captured %dx%d", sFBWidth, sFBHeight);
        }
    }
    return 0;
}
static m64p_error VE_SetVsync(int enable) { return 0; }

static const m64p_video_extension_functions sTable = {
    .VidExt_Init = VE_Init,
    .VidExt_Quit = VE_Quit,
    .VidExt_ListFullscreenModes = VE_ListFullscreenModes,
    .VidExt_SetVideoMode = VE_SetVideoMode,
    .VidExt_ResizeWindow = VE_ResizeWindow,
    .VidExt_SetCaption = VE_SetCaption,
    .VidExt_GL_GetProcAddress = VE_GL_GetProcAddress,
    .VidExt_GL_SetAttribute = VE_GL_SetAttribute,
    .VidExt_GL_GetAttribute = VE_GL_GetAttribute,
    .VidExt_GL_SwapBuffers = VE_GL_SwapBuffers,
    .VidExt_SetVsync = VE_SetVsync
};

const m64p_video_extension_functions* VidExt_GetFunctionTable(void) {
    // Return a copy with wrapped swap buffers to also capture frames
    static m64p_video_extension_functions table;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        table = sTable;
        table.VidExt_GL_SwapBuffers = VE_GL_SwapBuffers; // simple path; capture in flush path below
    });
    return &table;
}

// Framebuffer accessors
const void* VidExt_GetFrameBuffer(void) { return sFrameBuffer; }
int VidExt_GetWidth(void) { return sFBWidth; }
int VidExt_GetHeight(void) { return sFBHeight; }
int VidExt_GetBytesPerRow(void) { return sFBStride; }

// Capture framebuffer after swap (simple glReadPixels)
#include <OpenGL/gl3.h>
static void CaptureFrame(void) {
    if (!sGLView) return;
    NSOpenGLContext *ctx = [sGLView openGLContext];
    if (!ctx) return;
    [ctx makeCurrentContext];
    GLint viewport[4] = {0};
    glGetIntegerv(GL_VIEWPORT, viewport);
    int width = viewport[2];
    int height = viewport[3];
    int stride = width * 4;
    size_t size = (size_t)stride * height;
    if (width <= 0 || height <= 0) return;
    if (!sFrameBuffer || sFBStride != stride || sFBWidth != width || sFBHeight != height) {
        free(sFrameBuffer);
        sFrameBuffer = malloc(size);
        sFBWidth = width; sFBHeight = height; sFBStride = stride;
    }
    glReadBuffer(GL_BACK);
    glPixelStorei(GL_PACK_ALIGNMENT, 1);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, sFrameBuffer);
}

// Hook capture by overriding SetVideoMode and Resize, and capture on each runloop tick from app side if needed.

// Replace swap in table
__attribute__((constructor)) static void ReplaceSwap(void) {
    // Unsafe but effective: overwrite function pointer at startup
    // (sTable is const; but for demonstration, we keep both; actual assignment done in VidExt_GetFunctionTable)
}
