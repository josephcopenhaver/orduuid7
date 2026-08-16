// orduuid7 - x86_64 Linux, freestanding.
//
// The whole file is the memory image: a hand-written ELF header and one
// PT_LOAD are emitted as data, and the link step (tiny.ld + --oformat=binary)
// just concatenates it. No sections, no symtab, no dynamic loader.

.intel_syntax noprefix
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
    .short  62              // e_machine   = EM_X86_64
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
    .quad   0x1000          // p_align
_ehdr_end:

// Stack frame (80 bytes):
//   [rsp+ 0] ts[2]   timespec { sec, nsec }
//   [rsp+16] raw[16] the 16 raw id bytes
//   [rsp+32] out[33] 32 hex chars + '\n'
.globl _start
_start:
    sub     rsp, 80

    // clock_gettime(CLOCK_REALTIME, &ts)
    xor     edi, edi
    mov     rsi, rsp
    mov     eax, 228
    syscall

    // getrandom(raw + 6, 10, 0)
    lea     rdi, [rsp+22]
    mov     esi, 10
    xor     edx, edx
    mov     eax, 318
    syscall

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

    // write(1, out, 33)
    mov     edi, 1
    lea     rsi, [rsp+32]
    mov     edx, 33
    mov     eax, 1
    syscall

    // exit_group(wrote != 33)
    cmp     rax, 33
    setne   al
    movzx   edi, al
    mov     eax, 231
    syscall

_end:
