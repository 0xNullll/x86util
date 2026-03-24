; --------------------------------------------------------
; test_memcpy_s.asm
;   purpose: tests x86_memcpy_s with 7 cases
;   case 1:  valid copy, expect original dest address returned
;   case 2:  null destination, expect -1
;   case 3:  null source, expect -1
;   case 4:  n exceeds dest size, expect -1
;   case 5:  dest size is zero, expect -1
;   case 6:  n equals dest size, expect original dest address
;   case 7:  verify bytes were actually copied correctly
;   build  : nasm -w+all -D WINDOWS -f win32   test_memcpy_s.asm -o test_memcpy_s.obj
;            nasm -w+all -D LINUX   -f elf32   test_memcpy_s.asm -o test_memcpy_s.obj
;            nasm -w+all -D MACOS   -f macho32 test_memcpy_s.asm -o test_memcpy_s.obj
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
extern  SYM(x86_memcpy_s)

section .data
    src         db "hello world", 0     ; 11 bytes + null
    src_size    equ $ - src             ; 12

    dst         times 16 db 0xAA        ; 16 bytes prefilled with 0xAA
    dst_size    equ $ - dst             ; 16

section .text

SYM(main):
    push    ebp
    mov     ebp, esp
    push    esi                         ; used in verify loop

    ; ---- case 1: valid copy, n < dest size ----
    push    8                           ; n = 8 bytes to copy
    push    src                         ; src address
    push    dst_size                    ; dest size = 16
    push    dst                         ; dest address
    call    SYM(x86_memcpy_s)
    add     esp, 16

    cmp     eax, -1                     ; should not fail
    je      .fail_case1
    cmp     eax, dst                    ; should return original dest address
    jne     .fail_case1

    ; ---- case 2: null destination, expect -1 ----
    push    8
    push    src
    push    dst_size
    push    0                           ; null dest
    call    SYM(x86_memcpy_s)
    add     esp, 16

    cmp     eax, -1                     ; should be -1
    jne     .fail_case2

    ; ---- case 3: null source, expect -1 ----
    push    8
    push    0                           ; null src
    push    dst_size
    push    dst
    call    SYM(x86_memcpy_s)
    add     esp, 16

    cmp     eax, -1                     ; should be -1
    jne     .fail_case3

    ; ---- case 4: n exceeds dest size, expect -1 ----
    push    32                          ; n = 32, bigger than dest size
    push    src
    push    dst_size                    ; dest size = 16
    push    dst
    call    SYM(x86_memcpy_s)
    add     esp, 16

    cmp     eax, -1                     ; should be -1
    jne     .fail_case4

    ; ---- case 5: dest size is zero, expect -1 ----
    push    8
    push    src
    push    0                           ; dest size = 0
    push    dst
    call    SYM(x86_memcpy_s)
    add     esp, 16

    cmp     eax, -1                     ; should be -1
    jne     .fail_case5

    ; ---- case 6: n equals dest size, expect original dest address ----
    push    dst_size                    ; n = dest size = 16
    push    src
    push    dst_size
    push    dst
    call    SYM(x86_memcpy_s)
    add     esp, 16

    cmp     eax, -1                     ; should not fail
    je      .fail_case6
    cmp     eax, dst                    ; should return original dest address
    jne     .fail_case6

    ; ---- case 7: verify bytes were actually copied correctly ----
    mov     ecx, 11                     ; src is 11 bytes
    mov     esi, dst
    mov     edi, src
.verify_loop:
    mov     al, [esi]
    cmp     al, [edi]                   ; dst byte should match src byte
    jne     .fail_case7
    inc     esi
    inc     edi
    dec     ecx
    jnz     .verify_loop

    ; ---- all cases passed ----
    mov     eax, 0
    pop     esi
    mov     esp, ebp
    pop     ebp
    ret

.fail_case1:
    mov     eax, 1
    pop     esi
    mov     esp, ebp
    pop     ebp
    ret

.fail_case2:
    mov     eax, 2
    pop     esi
    mov     esp, ebp
    pop     ebp
    ret

.fail_case3:
    mov     eax, 3
    pop     esi
    mov     esp, ebp
    pop     ebp
    ret

.fail_case4:
    mov     eax, 4
    pop     esi
    mov     esp, ebp
    pop     ebp
    ret

.fail_case5:
    mov     eax, 5
    pop     esi
    mov     esp, ebp
    pop     ebp
    ret

.fail_case6:
    mov     eax, 6
    pop     esi
    mov     esp, ebp
    pop     ebp
    ret

.fail_case7:
    mov     eax, 7
    pop     esi
    mov     esp, ebp
    pop     ebp
    ret