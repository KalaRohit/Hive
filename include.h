#if defined (_WIN_32)

#elif defined(__APPLE__) && defined(__MACH__)
    #include <objc/runtime.h>
    #include <objc/message.h>
#elif defined(__LINUX__)
#endif
