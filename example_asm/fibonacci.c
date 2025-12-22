#include "optnone.h"

void exception_handler();

__attribute__((section(
    ".bootinfo"))) volatile const unsigned long long exception_handler_addr =
    (unsigned long long)(void *)&exception_handler;
const static unsigned int step = 6;

__asm__(".section .text\n"
        "li $sp, _stack_top\n"
        "li $gp, __global_pointer$\n"
        "li $ra, 0x0d00\n" // placeholder
        "li $t9, __start\n"
        "jr $t9\n");

NONOPT void __start() {
    unsigned int prev = 0, curr = 1, sum = 0;
    for (unsigned int i = step; i > 0; i--) {
        sum = prev + curr;
        prev = curr;
        curr = sum;
    }
    // should be 13, F_6
    *(volatile unsigned long long *)0 = sum;
    while (1)
        ;
}

void exception_handler() {
    while (1)
        ;
}