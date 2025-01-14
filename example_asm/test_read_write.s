.section    .data
result_word:        .space      32
result_sb:          .space      16
word1:              .word       0x1BADB002
word2:              .word       0xDEADBEEF
bytes:              .byte       0x0
                    .byte       0x0
                    .byte       -0x11
                    .byte       0x31

.section    .text
.global     __start
__start:
    dla     $t0,        word1;
    dla     $t1,        result_word;
    lw      $t2,        0($t0);
    sd      $t2,        0($t1);
    lwu     $t2,        0($t0);
    sd      $t2,        8($t1);

    dla     $t0,        word2;
    lw      $t2,        0($t0);
    sd      $t2,        16($t1);
    lwu     $t2,        0($t0);
    sd      $t2,        24($t1);

    dla     $t0,        bytes;
    dla     $t1,        result_sb;
    lb      $t2,        0($t0);
    sw      $t2,        0($t1);
    lbu     $t2,        0($t0);
    sw      $t2,        4($t1);

    lb      $t2,        1($t0);
    sw      $t2,        8($t1);
    lbu     $t2,        1($t0);
    sw      $t2,        12($t1);
deadloop:
    j       deadloop;
