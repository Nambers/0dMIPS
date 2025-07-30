SECTIONS
{
    /DISCARD/ : {
        *(.eh_frame)
        *(.note*)
        *(.pdr)
        *(.MIPS.options)
        *(.got)
        *(.got.plt)
        *(.plt)
        *(.gnu.attributes)
        *(.MIPS.abiflags)
        *(.reginfo)
    }

    . = 0x0;

    .bootinfo : {
        KEEP(*(.boot*))
    }
    .comment : {
        *(.comment)
    }

    . = 0x100;

    .text : {
        *(.text)
        *(.text.*)
    }

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }

    .data : {
        PROVIDE(__global_pointer$ = .);
        *(.sdata)
        *(.data)
    }

    .bss (NOLOAD) : {
        *(.sbss)
        *(.bss)
        *(COMMON)
    }

    .stack (NOLOAD) : ALIGN(16) {
        _stack_bottom = .;
        . += 0x200;
        PROVIDE(_stack_top = .);
    }
}
