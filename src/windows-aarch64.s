// orduuid7 - aarch64 Windows.
//
// The ARM64 Windows ABI passes the first eight arguments in registers and has
// no shadow space, so all five WriteFile arguments fit in x0-x4. Entry is
// `mainCRTStartup`, the console-subsystem default, so no CRT is involved.

.text
.globl mainCRTStartup
.p2align 2

// Frame (80 bytes, 16-aligned):
//   [sp+ 0] ft      FILETIME: 100ns ticks since 1601-01-01
//   [sp+ 8] n       bytes written by WriteFile
//   [sp+16] raw[16] the 16 raw id bytes
//   [sp+32] out[33] 32 hex chars + '\n'
mainCRTStartup:
    sub     sp, sp, #80

    // GetSystemTimeAsFileTime(&ft)
    mov     x0, sp
    bl      GetSystemTimeAsFileTime

    // ProcessPrng(raw + 6, 10)
    add     x0, sp, #22
    mov     x1, #10
    bl      ProcessPrng

    // ms = (ft - 116444736000000000) / 10000
    ldr     x0, [sp]
    mov     x1, #0x8000                 // 116444736000000000
    movk    x1, #0xd53e, lsl #16
    movk    x1, #0xb1de, lsl #32
    movk    x1, #0x019d, lsl #48
    sub     x0, x0, x1
    mov     x1, #10000
    udiv    x0, x0, x1

    // raw[0..6] = low 48 bits of ms, big-endian
    lsl     x2, x0, #16
    rev     x2, x2
    str     w2, [sp, #16]
    lsr     x2, x2, #32
    strh    w2, [sp, #20]

    // raw[15] = (raw[15] & 0xc0) | TAG   (0x27 is not a logical immediate)
    ldrb    w3, [sp, #31]
    mov     w4, #0x27
    and     w3, w3, #0xc0
    orr     w3, w3, w4
    strb    w3, [sp, #31]

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

    mov     w4, #10                     // '\n'; x6 now points at out[32]
    strb    w4, [x6]

    // WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), out, 33, &n, NULL)
    mov     w0, #-11
    bl      GetStdHandle
    add     x1, sp, #32
    mov     w2, #33
    add     x3, sp, #8
    mov     x4, #0
    bl      WriteFile

    // ExitProcess(n != 33). WriteFile zeroes n before any work, so a failed
    // write leaves n != 33.
    ldr     w0, [sp, #8]
    cmp     w0, #33
    cset    w0, ne
    bl      ExitProcess
