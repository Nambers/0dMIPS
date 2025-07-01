# should run in SOC
.section .bootinfo, "a"
exception_handler_addr: .dword interrupt_handler
.data
str_msg:    .asciiz "Hello, World!\n"

.text
.global __start
__start:
    dla $t1, str_msg;
    # stdout mmio
    li $t0, 0x20000010;

print_loop:
    lb $t2, 0($t1);       # load byte
    beqz $t2, done;
    sb $t2, 0($t0);       # write to MMIO
    add $t1, $t1, 1;     # move to next byte
    j print_loop;

done:
interrupt_handler:
    j interrupt_handler;
    
