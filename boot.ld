OUTPUT_FORMAT(binary)
ENTRY(_boot_start)

SECTIONS
{
    . = 0x7C00;
    .text : { *(.text*) }
    /DISCARD/ : { *(.note*) *(.comment*) *(.eh_frame*) }
}
