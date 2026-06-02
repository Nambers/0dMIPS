#include "header.h"
#include "optnone.h"

void exception_handler();

const static unsigned int step = 6;

DEFAULT_HEADER_DEFINITIONS;

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