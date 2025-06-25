SECTIONS
{
    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
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

    .text : {
        *(.text)
        *(.text.*)
    }

    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }

    .data : {
        _gp = .;
        *(.sdata)
        *(.data)
    }

    .bss (NOLOAD) : {
        *(.sbss)
        *(.bss)
        *(COMMON)
    }
    . = ALIGN(16);
    _stack_bottom = .;
    . += 0x100;
    _stack_top = .;
    PROVIDE(_stack_top = .);
}
