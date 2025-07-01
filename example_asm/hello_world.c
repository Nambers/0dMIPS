#include <stdint.h>

void exception_handler();

__attribute__((unused, section(".bootinfo")))
const uint64_t exception_handler_addr = (uint64_t)(void *)&exception_handler;

static char *const stdout_mmio = (char *)(0x20000010);
static const uint64_t stdout_buffer_size = 8;

__asm__(".section .text\n"
        "li $sp, _stack_top\n"
        "li $gp, __global_pointer$\n"
        "li $ra, 0x0d00\n" // placeholder
        "li $t9, __start\n"
        "jr $t9\n");

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
