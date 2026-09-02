OUTPUT_FORMAT(binary)
ENTRY(_app_start)

SECTIONS
{
    . = 0;
    .text :
    {
        *(.text.entry)
        *(.text*)
    }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    /DISCARD/ : { *(.note*) *(.comment*) *(.eh_frame*) }
}
