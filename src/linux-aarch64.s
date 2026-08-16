// orduuid7 - aarch64 Linux, freestanding.
//
// The whole file is the memory image: a hand-written ELF header and one
// PT_LOAD are emitted as data, and the link step (tiny.ld + --oformat=binary)
// just concatenates it. No sections, no symtab, no dynamic loader.

.text

// ---------------------------------------------------------------- ELF header
_ehdr:
    .byte   0x7f, 'E', 'L', 'F'
    .byte   2               // EI_CLASS   = ELFCLASS64
    .byte   1               // EI_DATA    = ELFDATA2LSB
    .byte   1               // EI_VERSION = EV_CURRENT
    .byte   0               // EI_OSABI   = SYSV
    .quad   0               // EI_ABIVERSION + padding
    .short  2               // e_type      = ET_EXEC
    .short  183             // e_machine   = EM_AARCH64
    .long   1               // e_version
    .quad   _start          // e_entry
    .quad   _phdr - _ehdr   // e_phoff
    .quad   0               // e_shoff
    .long   0               // e_flags
    .short  _phdr - _ehdr   // e_ehsize
    .short  _ehdr_end - _phdr // e_phentsize
    .short  1               // e_phnum
    .short  0               // e_shentsize
    .short  0               // e_shnum
    .short  0               // e_shstrndx

// ------------------------------------------------------------ program header
_phdr:
    .long   1               // p_type   = PT_LOAD
    .long   5               // p_flags  = PF_R | PF_X
    .quad   0               // p_offset
    .quad   _ehdr           // p_vaddr
    .quad   _ehdr           // p_paddr
    .quad   _end - _ehdr    // p_filesz
    .quad   _end - _ehdr    // p_memsz
    .quad   0x10000         // p_align
_ehdr_end:

// Stack frame (80 bytes):
//   [sp+ 0] ts[2]   timespec { sec, nsec }
//   [sp+16] raw[16] the 16 raw id bytes
//   [sp+32] out[33] 32 hex chars + '\n'
.globl _start
_start:
    sub     sp, sp, #80

    // clock_gettime(CLOCK_REALTIME, &ts)
    mov     x0, #0
    mov     x1, sp
    mov     x8, #113
    svc     #0

    // getrandom(raw + 6, 10, 0)
    add     x0, sp, #22
    mov     x1, #10
    mov     x2, #0
    mov     x8, #278
    svc     #0

    // ms = ts.sec * 1000 + ts.nsec / 1000000
    ldp     x2, x3, [sp]
    mov     x4, #1000
    mul     x2, x2, x4
    mov     x5, #0x4240             // 1000000
    movk    x5, #0xf, lsl #16
    udiv    x3, x3, x5
    add     x2, x2, x3

    // raw[0..6] = low 48 bits of ms, big-endian
    lsl     x3, x2, #16
    rev     x3, x3
    str     w3, [sp, #16]
    lsr     x3, x3, #32
    strh    w3, [sp, #20]

    // raw[15] = (raw[15] & 0xc0) | TAG   (0x27 is not a logical immediate)
    ldrb    w4, [sp, #31]
    mov     w5, #0x27
    and     w4, w4, #0xc0
    orr     w4, w4, w5
    strb    w4, [sp, #31]

    // hex-encode raw[0..16] into out[0..32]
    add     x5, sp, #16
    add     x6, sp, #32
    mov     x7, #16
1:  ldrb    w4, [x5], #1
    lsr     w9, w4, #4
    and     w10, w4, #15
    add     w11, w9, #0x30
    add     w12, w9, #0x57
    cmp     w9, #9
    csel    w11, w11, w12, ls
    strb    w11, [x6], #1
    add     w11, w10, #0x30
    add     w12, w10, #0x57
    cmp     w10, #9
    csel    w11, w11, w12, ls
    strb    w11, [x6], #1
    subs    x7, x7, #1
    b.ne    1b

    mov     w4, #10                 // '\n'; x6 now points at out[32]
    strb    w4, [x6]

    // write(1, out, 33)
    mov     x0, #1
    add     x1, sp, #32
    mov     x2, #33
    mov     x8, #64
    svc     #0

    // exit_group(wrote != 33)
    cmp     x0, #33
    cset    w0, ne
    mov     x8, #94
    svc     #0

_end:
