// should run in SOC
void exception_handler();

__attribute__((section(
    ".bootinfo"))) volatile const unsigned long long exception_handler_addr =
    (unsigned long long)(void *)&exception_handler;
const static unsigned int step = 12; // should be >= 12

__asm__(".section .text\n"
        "li $sp, _stack_top\n"
        "li $gp, _gp\n"
        "li $ra, 0x0d00\n" // placeholder
        "li $t9, __start\n"
        "jr $t9\n");
void __start() {
    unsigned int curr = *(unsigned int *)(0x20000000);
    curr += step;
    *(unsigned int *)(0x20000000) =
        curr; // set interrupting after num_cycle cycles
    while (1)
        ;
}

__attribute__((noreturn)) void exception_handler() {
    // Acknowledge the interrupt
    *(unsigned int *)(0x20000004) = 1;
    __asm__ volatile("eret");
    while (1)
        ;
}
