.data
exception_handler_addr: .dword interrupt_handler
num_cycle:	.word 6

.text
.global __start
__start:
    la $t0, num_cycle;
    lw $t1, 0($t0);
    # load current cycle into reg t0 0x2000_0000
    lw $t0, 0x20000000;
    add $t1, $t1, $t0;
    # set interrupting after num_cycle cycles
    sw $t1, 0x20000000;
    nop; nop; nop; nop;
    # no reachable
    li $t3, 0xcafebabe;
.org 0x120
interrupt_handler:
	#lw	$k0, 12($k1)		# $26 = 0x2000_0004
    li $k0, 0x20000004
	sw	$k1, 0($k0)		# acknowledge interrupt
	add	$k1, $zero, $k0		# $27 = 0x2000_0004
    or $t2, 0xdeadbeef;
	eret
