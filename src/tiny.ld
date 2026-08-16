/* Lay the single .text section (ELF header + code) flat at the load address.
   OUTPUT_FORMAT(binary) makes lld write the raw memory image with no ELF
   container of its own - the hand-written header in the source is the file. */
OUTPUT_FORMAT(binary)
ENTRY(_start)
SECTIONS {
    . = 0x10000;
    .all : { *(.text) }
    /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) *(.debug*) }
}
