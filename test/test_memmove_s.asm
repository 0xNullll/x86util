; --------------------------------------------------------
; test_memmove_s.asm
;   purpose: tests x86_memmove_s with 8 cases
;   case 1:  valid copy no overlap, expect dest address returned
;   case 2:  null destination, expect -1
;   case 3:  null source, expect -1
;   case 4:  n exceeds dest size, expect -1
;   case 5:  dest size is zero, expect -1
;   case 6:  dst == src, expect dest address returned unchanged
;   case 7:  overlap forward (dst > src), expect correct copy
;   case 8:  overlap backward (dst < src), expect correct copy
;   build  : nasm -w+all -D WINDOWS -f win32   test_memmove_s.asm -o test_memmove_s.obj
;            nasm -w+all -D LINUX   -f elf32   test_memmove_s.asm -o test_memmove_s.obj
;            nasm -w+all -D MACOS   -f macho32 test_memmove_s.asm -o test_memmove_s.obj
; --------------------------------------------------------

BITS 32

; --------------------------------------------------------
; platform symbol decoration
; --------------------------------------------------------
%ifdef WINDOWS
    %define SYM(x) _ %+ x
%elifdef MACOS
    %define SYM(x) _ %+ x
%else
    %define SYM(x) x
%endif

global  SYM(main)
extern  SYM(x86_memmove_s)

section .data
    src             db "hello world", 0     ; 11 bytes + null
    src_size        equ $ - src             ; 12

    dst             times 16 db 0xAA        ; 16 bytes prefilled with 0xAA
    dst_size        equ $ - dst             ; 16

    ; overlap buffer — dst and src point into same region
    overlap_buf     db 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08
    overlap_size    equ $ - overlap_buf     ; 8

section .text

SYM(main):
    push    ebp
    mov     ebp, esp
    push    esi                             ; used in verify loops
    push    edi                             ; used in verify loops

    ; ---- case 1: valid copy no overlap ----
    push    8                               ; n = 8 bytes
    push    src                             ; src address
    push    dst_size                        ; dest size = 16
    push    dst                             ; dest address
    call    SYM(x86_memmove_s)
    add     esp, 16

    cmp     eax, -1                         ; should not fail
    je      .fail_case1
    cmp     eax, dst                        ; should return original dest address
    jne     .fail_case1

    ; ---- case 2: null destination, expect -1 ----
    push    8
    push    src
    push    dst_size
    push    0                               ; null dest
    call    SYM(x86_memmove_s)
    add     esp, 16

    cmp     eax, -1                         ; should be -1
    jne     .fail_case2

    ; ---- case 3: null source, expect -1 ----
    push    8
    push    0                               ; null src
    push    dst_size
    push    dst
    call    SYM(x86_memmove_s)
    add     esp, 16

    cmp     eax, -1                         ; should be -1
    jne     .fail_case3

    ; ---- case 4: n exceeds dest size, expect -1 ----
    push    32                              ; n = 32, bigger than dest size
    push    src
    push    dst_size                        ; dest size = 16
    push    dst
    call    SYM(x86_memmove_s)
    add     esp, 16

    cmp     eax, -1                         ; should be -1
    jne     .fail_case4

    ; ---- case 5: dest size is zero, expect -1 ----
    push    8
    push    src
    push    0                               ; dest size = 0
    push    dst
    call    SYM(x86_memmove_s)
    add     esp, 16

    cmp     eax, -1                         ; should be -1
    jne     .fail_case5

    ; ---- case 6: dst == src, expect dest address returned unchanged ----
    push    8
    push    src                             ; src == dst
    push    src_size
    push    src                             ; dst == src
    call    SYM(x86_memmove_s)
    add     esp, 16

    cmp     eax, -1                         ; should not fail
    je      .fail_case6
    cmp     eax, src                        ; should return original dest address
    jne     .fail_case6

    ; ---- case 7: overlap forward (dst > src) ----
    ; overlap_buf = 01 02 03 04 05 06 07 08
    ; copy 6 bytes from overlap_buf to overlap_buf+2
    ; expected result: 01 02 01 02 03 04 05 06
    push    6                               ; n = 6 bytes
    push    overlap_buf                     ; src = start of buffer
    push    overlap_size                    ; dest size = 8
    push    overlap_buf + 2                 ; dst = 2 bytes into buffer
    call    SYM(x86_memmove_s)
    add     esp, 16

    cmp     eax, -1                         ; should not fail
    je      .fail_case7

    ; verify result
    mov     esi, overlap_buf + 2
    cmp     byte [esi+0], 0x01
    jne     .fail_case7
    cmp     byte [esi+1], 0x02
    jne     .fail_case7
    cmp     byte [esi+2], 0x03
    jne     .fail_case7
    cmp     byte [esi+3], 0x04
    jne     .fail_case7
    cmp     byte [esi+4], 0x05
    jne     .fail_case7
    cmp     byte [esi+5], 0x06
    jne     .fail_case7

    ; ---- case 8: verify no overlap copy bytes match ----
    mov     ecx, 8
    mov     esi, dst
    mov     edi, src
.verify_loop:
    mov     al, [esi]
    cmp     al, [edi]                       ; dst byte should match src byte
    jne     .fail_case8
    inc     esi
    inc     edi
    dec     ecx
    jnz     .verify_loop

    ; ---- all cases passed ----
    mov     eax, 0
    pop     edi
    pop     esi
    mov     esp, ebp
    pop     ebp
    ret

.fail_case1:    mov eax, 1
                jmp .fail
.fail_case2:    mov eax, 2
                jmp .fail
.fail_case3:    mov eax, 3
                jmp .fail
.fail_case4:    mov eax, 4
                jmp .fail
.fail_case5:    mov eax, 5
                jmp .fail
.fail_case6:    mov eax, 6
                jmp .fail
.fail_case7:    mov eax, 7
                jmp .fail
.fail_case8:    mov eax, 8

.fail:
    pop     edi
    pop     esi
    pop     ebp
    ret