// orduuid7 - x86_64 macOS.
//
// macOS gives no stable syscall ABI, so this calls libSystem rather than
// trapping directly. The binary uses LC_MAIN, so `_main` is the entry and
// libdyld passes our return value to exit().
//
// Calls go through the GOT rather than direct, which keeps the linker from
// emitting lazy stubs; that drops the whole __DATA segment.

.intel_syntax noprefix
.text
.globl _main
.p2align 4

// Frame (88 bytes; entry rsp%16==8, so this realigns to 0 for calls):
//   [rsp+ 0] ts[2]   timespec { sec, nsec }
//   [rsp+16] raw[16] the 16 raw id bytes
//   [rsp+32] out[33] 32 hex chars + '\n'
_main:
    sub     rsp, 88

    // clock_gettime(CLOCK_REALTIME, &ts)
    xor     edi, edi
    mov     rsi, rsp
    call    qword ptr [rip + _clock_gettime@GOTPCREL]

    // getentropy(raw + 6, 10)
    lea     rdi, [rsp+22]
    mov     esi, 10
    call    qword ptr [rip + _getentropy@GOTPCREL]

    // ms = ts.sec * 1000 + ts.nsec / 1000000   (nsec < 1e9, so 32-bit div)
    mov     eax, [rsp+8]
    xor     edx, edx
    mov     ecx, 1000000
    div     ecx
    mov     rcx, [rsp]
    imul    rcx, rcx, 1000
    add     rax, rcx

    // raw[0..6] = low 48 bits of ms, big-endian
    shl     rax, 16
    bswap   rax
    mov     [rsp+16], eax
    shr     rax, 32
    mov     [rsp+20], ax

    // raw[15] = (raw[15] & 0xc0) | TAG
    and     byte ptr [rsp+31], 0xc0
    or      byte ptr [rsp+31], 0x27

    // hex-encode raw[0..16] into out[0..32]
    xor     ecx, ecx
1:  movzx   eax, byte ptr [rsp+rcx+16]
    mov     edx, eax
    shr     eax, 4
    add     al, 0x30
    cmp     al, 0x39
    jbe     2f
    add     al, 0x27
2:  mov     [rsp+rcx*2+32], al
    and     dl, 15
    add     dl, 0x30
    cmp     dl, 0x39
    jbe     3f
    add     dl, 0x27
3:  mov     [rsp+rcx*2+33], dl
    inc     rcx
    cmp     cl, 16
    jne     1b

    mov     byte ptr [rsp+64], '\n'

    // return write(1, out, 33) != 33
    mov     edi, 1
    lea     rsi, [rsp+32]
    mov     edx, 33
    call    qword ptr [rip + _write@GOTPCREL]

    cmp     rax, 33
    setne   al
    movzx   eax, al
    add     rsp, 88
    ret
