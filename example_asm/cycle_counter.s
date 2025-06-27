# should run in SOC
.section .bootinfo, "a"
exception_handler_addr: .dword interrupt_handler
.data
num_cycle:	.word 7 # should >= 7

.text
.global __start
__start:
    dla $t0, num_cycle;
    lw $t1, 0($t0);
    # load current cycle into reg t0 0x2000_0000
    lw $t0, 0x20000000;
    add $t1, $t1, $t0;
    # set interrupting after num_cycle cycles
    sw $t1, 0x20000000;
    nop;
    # no reachable, but will run till EX(if num_cycle == 7)
    li $t3, 0xcafebabe;

.org 0x300
interrupt_handler:
	#lw	$k0, 12($k1)		# $26 = 0x2000_0004
    li $t0, 0x20000004;
    li $t1, 1;
	sw	$t1, 0($t0);		# acknowledge interrupt
	eret;
