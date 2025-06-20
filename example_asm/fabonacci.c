void exception_handler();

__attribute__((section(
    ".data"))) volatile const unsigned long long exception_handler_addr =
    (unsigned long long)(void *)&exception_handler;
__attribute__((section(".data"))) volatile const unsigned int step = 6;

__asm__(
    ".section .text\n"
    "lui $sp, %hi(_stack_top)\n"
    "ori $sp, $sp, %lo(_stack_top)\n");

void __start() {
    unsigned int prev = 0, curr = 1, sum = 0;
    for (unsigned int i = step; i > 0; i--) {
        sum = prev + curr;
        prev = curr;
        curr = sum;
    }
    // should be 8
    *(unsigned long long *)0 = sum;
    while (1);
}

void exception_handler() { while (1); }