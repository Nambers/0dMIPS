.data
num_cycle:	.word 1

.text
.global __start
__start:
    la $t0, num_cycle;
    lw $t1, 0($t0);
    # load current cycle into reg t0 FFFF001C
    lw $t0, 0xFFFF001C;
    add $t1, $t1, $t0;
    # set interrupting after num_cycle cycles
    sw $t1, 0xFFFF001C;
    nop; nop;
    or $t3, 0xcafebabe;
.org 0x200
interrupt_handler:
	lw	$k0, 12($k1)		# $26 = 0xffff006c
	sw	$k1, 0($k0)		# acknowledge interrupt
	add	$k1, $zero, $k0		# $27 = 0xffff006c
    or $t2, 0xdeadbeef;
	eret
