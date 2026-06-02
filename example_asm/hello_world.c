#include "header.h"
#include <stdint.h>

void exception_handler();

static char *const stdout_mmio = (char *)(0x20000010);
static const uint64_t stdout_buffer_size = 8;

DEFAULT_HEADER_DEFINITIONS;

void puts_(const char *str) {
    while (str[0]) {
        uint64_t i = 0;
        char buf[8];
        for (; str[i] != '\0' && i < stdout_buffer_size - 1; ++i) {
            buf[i] = str[i];
        }
        buf[i] = '\0';
        str += i;
        *(uint64_t *)stdout_mmio = *(uint64_t *)buf;
    }
}

void __start() {
    puts_("Hello, World!\n");
    while (1)
        ; // prevent exit
}

void exception_handler() {
    while (1)
        ;
}
