// orduuid7 - arm64 macOS.
//
// macOS gives no stable syscall ABI and dyld refuses arm64 images that do not
// link libSystem, so this calls libSystem rather than trapping directly. The
// binary uses LC_MAIN, so `_main` is the entry and libdyld passes our return
// value to exit().
//
// Calls go through the GOT rather than `bl`, which keeps the linker from
// emitting lazy stubs; that drops the whole __DATA segment (16 KB of padding).

.text
.globl _main
.p2align 2

// Frame (96 bytes):
//   [sp+ 0] saved x29 / x30
//   [sp+16] ts[2]   timespec { sec, nsec }
//   [sp+32] raw[16] the 16 raw id bytes
//   [sp+48] out[33] 32 hex chars + '\n'
_main:
    stp     x29, x30, [sp, #-96]!

    // clock_gettime(CLOCK_REALTIME, &ts)
    mov     x0, #0
    add     x1, sp, #16
    adrp    x16, _clock_gettime@GOTPAGE
    ldr     x16, [x16, _clock_gettime@GOTPAGEOFF]
    blr     x16

    // getentropy(raw + 6, 10)
    add     x0, sp, #38
    mov     x1, #10
    adrp    x16, _getentropy@GOTPAGE
    ldr     x16, [x16, _getentropy@GOTPAGEOFF]
    blr     x16

    // ms = ts.sec * 1000 + ts.nsec / 1000000
    ldp     x2, x3, [sp, #16]
    mov     x4, #1000
    mul     x2, x2, x4
    mov     x5, #0x4240             // 1000000
    movk    x5, #0xf, lsl #16
    udiv    x3, x3, x5
    add     x2, x2, x3

    // raw[0..6] = low 48 bits of ms, big-endian
    lsl     x3, x2, #16
    rev     x3, x3
    str     w3, [sp, #32]
    lsr     x3, x3, #32
    strh    w3, [sp, #36]

    // raw[15] = (raw[15] & 0xc0) | TAG   (0x27 is not a logical immediate)
    ldrb    w4, [sp, #47]
    mov     w5, #0x27
    and     w4, w4, #0xc0
    orr     w4, w4, w5
    strb    w4, [sp, #47]

    // hex-encode raw[0..16] into out[0..32]
    add     x5, sp, #32
    add     x6, sp, #48
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

    // return write(1, out, 33) != 33
    mov     x0, #1
    add     x1, sp, #48
    mov     x2, #33
    adrp    x16, _write@GOTPAGE
    ldr     x16, [x16, _write@GOTPAGEOFF]
    blr     x16

    cmp     x0, #33
    cset    w0, ne
    ldp     x29, x30, [sp], #96
    ret
