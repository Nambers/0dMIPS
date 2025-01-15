SECTIONS
{
    /DISCARD/ : { *(.note*) *(.eh_frame) *(.comment) }
    . = 0x0;
    .text : { *(.text) }
    .data : { *(.data) }
}
   