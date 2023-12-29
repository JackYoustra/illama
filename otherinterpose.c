#include <stdio.h>
#include <stdarg.h>

#define DYLD_INTERPOSE(_replacement, _replacee) \
    __attribute__((used)) static struct { \
        const void* replacement; \
        const void* replacee; \
    } _interpose_##_replacee __attribute__ ((section("__DATA, __interpose"))) = { \
        (const void*) (unsigned long) &_replacement, \
        (const void*) (unsigned long) &_replacee \
    };

// forward printf with vprintf
int my_printf(const char *format, ...){
    printf("Hello from interpose\n");
    va_list args;
    va_start(args, format);
    int ret = vprintf(format, args);
    va_end(args);
    return ret;
}
DYLD_INTERPOSE(my_printf,printf);

// interpose fprintf
int my_fprintf(FILE *stream, const char *format, ...){
    printf("Hello from interpose\n");
    va_list args;
    va_start(args, format);
    int ret = vfprintf(stream, format, args);
    va_end(args);
    return ret;
}
DYLD_INTERPOSE(my_fprintf,fprintf);