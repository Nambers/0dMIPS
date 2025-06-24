#include <stdint.h>

void exception_handler();

__attribute__((section(".data"))) volatile const int64_t exception_handler_addr =
    (int64_t)(void*)&exception_handler;

static volatile char* const stdout_mmio        = (volatile char*)(uintptr_t)(0x20000010);
static const int64_t        stdout_buffer_size = 8;

__asm__(".section .text\n"
        "lui $sp, %hi(_stack_top)\n"
        "ori $sp, $sp, %lo(_stack_top)\n"
        "li $ra, 0x0d00\n"
        "j __start\n");

int64_t puts_buf(const char* str) {
    int64_t i = 0;
    while (str[i] != '\0' && i < stdout_buffer_size - 1) {
        *(stdout_mmio + i) = str[i];
        i++;
    }
    stdout_mmio[i] = '\0';
    return i - 1;
}

void puts_(const char* str) {
    while (*str) {
        int64_t len = puts_buf(str);
        str += len;
    }
}

void __start() {
    puts_("Hello, World!\n");
    while (1); // prevent exit
}

void exception_handler() {
    while (1);
}
