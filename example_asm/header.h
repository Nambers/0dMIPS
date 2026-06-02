#define DEFINE_EXCEPTION                                                       \
    __asm__(".section .bootinfo,\"ax\"\n"                                      \
            ".balign 8\n"                                                      \
            "exception_handler_addr:\n"                                        \
            "jal exception_handler\n"                                          \
            "nop\n"                                                            \
            ".text\n")

#define DEFINE_ENTRY_POINT                                                     \
    __asm__(".section .text\n"                                                 \
            "li $sp, _stack_top\n"                                             \
            "li $gp, _gp\n"                                                    \
            "li $ra, 0x0d00\n" /* placeholder */                               \
            "li $t9, __start\n"                                                \
            "jr $t9\n")

#define DEFAULT_HEADER_DEFINITIONS                                             \
    DEFINE_EXCEPTION;                                                          \
    DEFINE_ENTRY_POINT