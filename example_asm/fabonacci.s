.data
step:	.word 6

.text
.global __start
__start:
    # load step addr into $t0 as double word(64bits)
	dla $t0, step;
	lw $t0, 0($t0);
	# prev
	or $t1, $0, 0;
	# curr
	or $t2, $0, 1;
	bne $t0, 0, is_z_end;
		or $v0, $0, $t1;
		j end;
	is_z_end:
	bne $t0, 1, is_o_end;
		or $v0, $0, $t2;
		beq $0, $0, end;
	is_o_end:
	# sum
	or $t3, $0, $0;
	j loop_end;
	loop_start:
		add $t3, $t1, $t2;
		or $t1, $t2, $0;
		or $t2, $t3, $0;
		sub $t0, $t0, 1;
	loop_end:
		bne $t0, 1, loop_start;

	end:
    # should be 8 in reg2($v0)
	or $v0, $0, $t3;
	sw $0, 4($0);
	# memory dump 0x0 should be 8
	sw $v0, 0($0);
	# exit
	deaploop:
		j deaploop;
