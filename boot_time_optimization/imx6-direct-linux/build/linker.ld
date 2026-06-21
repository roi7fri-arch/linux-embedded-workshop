OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

SECTIONS
{
    . = 0x12000000;

    .text : ALIGN(4) {
        KEEP(*(.text.start))
        *(.text*)
        *(.rodata*)
    }

    . = ALIGN(64);
    __image_zimage_start = .;
    .image_zimage : ALIGN(64) {
        KEEP(*(.image_zimage))
    }
    __image_zimage_end = .;

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.ARM.attributes)
        *(.eh_frame*)
        *(.interp)
        *(.dynamic)
        *(.dynsym)
        *(.dynstr)
        *(.hash)
        *(.gnu*)
    }
}