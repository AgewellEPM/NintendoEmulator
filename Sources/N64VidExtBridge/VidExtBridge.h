#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int32_t m64p_error;
typedef void* m64p_function;

typedef enum {
    M64VIDEO_WINDOWED = 1,
    M64VIDEO_FULLSCREEN = 2
} m64p_video_mode;

typedef enum {
    M64P_GL_DOUBLEBUFFER = 1,
    M64P_GL_BUFFER_SIZE,
    M64P_GL_DEPTH_SIZE,
    M64P_GL_RED_SIZE,
    M64P_GL_GREEN_SIZE,
    M64P_GL_BLUE_SIZE,
    M64P_GL_ALPHA_SIZE,
    M64P_GL_SWAP_CONTROL
} m64p_GLattr;

typedef struct m64p_video_extension_functions_s {
    m64p_error (*VidExt_Init)(void);
    m64p_error (*VidExt_Quit)(void);
    m64p_error (*VidExt_ListFullscreenModes)(void* Sizes, int* NumSizes);
    m64p_error (*VidExt_SetVideoMode)(int Width, int Height, int BPP, m64p_video_mode Mode, int Flags);
    m64p_error (*VidExt_ResizeWindow)(int Width, int Height);
    m64p_error (*VidExt_SetCaption)(const char* Caption);
    m64p_function (*VidExt_GL_GetProcAddress)(const char* Proc);
    m64p_error (*VidExt_GL_SetAttribute)(m64p_GLattr Attr, int Value);
    m64p_error (*VidExt_GL_GetAttribute)(m64p_GLattr Attr, int* Value);
    m64p_error (*VidExt_GL_SwapBuffers)(void);
    m64p_error (*VidExt_SetVsync)(int Enable);
} m64p_video_extension_functions;

const m64p_video_extension_functions* VidExt_GetFunctionTable(void);

// Framebuffer accessors (RGBA8)
const void* VidExt_GetFrameBuffer(void);
int VidExt_GetWidth(void);
int VidExt_GetHeight(void);
int VidExt_GetBytesPerRow(void);

#ifdef __cplusplus
}
#endif
