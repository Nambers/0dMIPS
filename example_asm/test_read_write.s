.section    .data
    result:         .space      4
    result_b:       .space      1
    .align 2 
    w:              .word       0xDEADBEEF
    .align 2 
    b:              .word       0x41

.section    .text
                .global     __start
__start:
    dla     $t0,                w;
    lw      $t0,                0($t0);
    dla     $t1,                b;
    lb      $t1,                0($t1);
    dla     $t2,                result;
    sw      $t0,                0($t2);
    dla     $t2,                result_b;
    sb      $t1,                0($t2);
deadloop:
    j       deadloop;
