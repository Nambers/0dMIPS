void exception_handler();

__attribute__((section(
    ".data"))) volatile const unsigned long long exception_handler_addr =
    (unsigned long long)(void *)&exception_handler;
__attribute__((section(".data"))) volatile const unsigned int step = 6;

void __start() {
    unsigned int prev = 0, curr = 1, sum = 0;
    for (unsigned int i = 0; i < step; i++) {
        sum = prev + curr;
        prev = curr;
        curr = sum;
    }
    // should be 8
    *(unsigned int *)0 = sum;
    while (1);
}

void exception_handler() { while (1); }