// orduuid7 - x86_64 Windows.
//
// Calls go through the __imp_ pointers directly so the linker does not have to
// emit a jump thunk per import. Entry is `mainCRTStartup`, the console-subsystem
// default, so no CRT is involved.

.intel_syntax noprefix
.text
.globl mainCRTStartup
.p2align 4

// Frame (144 bytes, 16-aligned):
//   [rsp+  0] 32-byte shadow space for callees, then the 5th WriteFile arg
//   [rsp+ 64] ft      FILETIME: 100ns ticks since 1601-01-01
//   [rsp+ 72] n       bytes written by WriteFile
//   [rsp+ 80] raw[16] the 16 raw id bytes
//   [rsp+ 96] out[33] 32 hex chars + '\n'
mainCRTStartup:
    and     rsp, -16
    sub     rsp, 144

    // GetSystemTimeAsFileTime(&ft)
    lea     rcx, [rsp+64]
    call    qword ptr [rip + __imp_GetSystemTimeAsFileTime]

    // ProcessPrng(raw + 6, 10)
    lea     rcx, [rsp+86]
    mov     edx, 10
    call    qword ptr [rip + __imp_ProcessPrng]

    // ms = (ft - 116444736000000000) / 10000
    mov     rax, [rsp+64]
    movabs  rcx, 116444736000000000
    sub     rax, rcx
    xor     edx, edx
    mov     ecx, 10000
    div     rcx

    // raw[0..6] = low 48 bits of ms, big-endian
    shl     rax, 16
    bswap   rax
    mov     [rsp+80], eax
    shr     rax, 32
    mov     [rsp+84], ax

    // raw[15] = (raw[15] & 0xc0) | TAG
    and     byte ptr [rsp+95], 0xc0
    or      byte ptr [rsp+95], 0x27

    // hex-encode raw[0..16] into out[0..32]
    xor     ecx, ecx
1:  movzx   eax, byte ptr [rsp+rcx+80]
    mov     edx, eax
    shr     eax, 4
    add     al, 0x30
    cmp     al, 0x39
    jbe     2f
    add     al, 0x27
2:  mov     [rsp+rcx*2+96], al
    and     dl, 15
    add     dl, 0x30
    cmp     dl, 0x39
    jbe     3f
    add     dl, 0x27
3:  mov     [rsp+rcx*2+97], dl
    inc     rcx
    cmp     cl, 16
    jne     1b

    mov     byte ptr [rsp+128], '\n'

    // WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), out, 33, &n, NULL)
    mov     ecx, -11
    call    qword ptr [rip + __imp_GetStdHandle]
    mov     rcx, rax
    lea     rdx, [rsp+96]
    mov     r8d, 33
    lea     r9, [rsp+72]
    mov     qword ptr [rsp+32], 0
    call    qword ptr [rip + __imp_WriteFile]

    // ExitProcess(n != 33). WriteFile zeroes n before any work, so a failed
    // write leaves n != 33.
    xor     ecx, ecx
    cmp     dword ptr [rsp+72], 33
    setne   cl
    call    qword ptr [rip + __imp_ExitProcess]
