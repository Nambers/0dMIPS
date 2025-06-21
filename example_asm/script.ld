SECTIONS
{
    /DISCARD/ : { *(.note*) *(.eh_frame) *(.comment) }
    . = 0x0;
    .text : { KEEP(*(.text)) }
    .data : { 
        *(.data)
        /* stack */
        *(.stack)
        *(.stack.*)
        . = ALIGN(16);
        _stack_bottom = .;
        . += 0x100;  /* stack size */
        _stack_top = .;
    }
}
   