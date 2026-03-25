; --------------------------------------------------------
; test_memset_s.asm
;   purpose: tests x86_memset_s with 7 cases
;   case 1:  valid buffer, expect original pointer returned
;   case 2:  null pointer, expect -1
;   case 3:  n exceeds smax, expect -1
;   case 4:  smax is zero, expect -1
;   case 5:  n equals smax, expect original pointer returned
;   case 6:  verify bytes were actually written
;   case 7:  returned address matches original address exactly
;   build  : nasm -w+all -D WINDOWS -f win32   test_memset_s.asm -o test_memset_s.obj
;            nasm -w+all -D LINUX   -f elf32   test_memset_s.asm -o test_memset_s.obj
;            nasm -w+all -D MACOS   -f macho32 test_memset_s.asm -o test_memset_s.obj
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

global SYM(main)
extern SYM(x86_memset_s)

section .data
    buf         times 16 db 0xAA   ; 16 bytes prefilled with 0xAA
    buf_size    equ $ - buf         ; 16

section .text

SYM(main):
    push    ebp
    mov     ebp, esp
    push    esi                     ; save esi — used in verify loop

    ; ---- case 1: valid buffer, n < smax ----
    push    8                       ; n = 8 bytes to fill
    push    0x42                    ; fill byte
    push    buf_size                ; smax = 16
    push    buf                     ; pointer
    call    SYM(x86_memset_s)
    add     esp, 16

    cmp     eax, -1                 ; should not fail
    je      .fail_case1
    cmp     eax, buf                ; should return original pointer
    jne     .fail_case1

    ; ---- case 2: null pointer, expect -1 ----
    push    8
    push    0x42
    push    16
    push    0                       ; null pointer
    call    SYM(x86_memset_s)
    add     esp, 16

    cmp     eax, -1                 ; should be -1
    jne     .fail_case2

    ; ---- case 3: n exceeds smax, expect -1 ----
    push    32                      ; n = 32, bigger than smax
    push    0x42
    push    16                      ; smax = 16
    push    buf
    call    SYM(x86_memset_s)
    add     esp, 16

    cmp     eax, -1                 ; should be -1
    jne     .fail_case3

    ; ---- case 4: smax is zero, expect -1 ----
    push    0
    push    0x42
    push    0                       ; smax = 0
    push    buf
    call    SYM(x86_memset_s)
    add     esp, 16

    cmp     eax, -1                 ; should be -1
    jne     .fail_case4

    ; ---- case 5: n equals smax, expect original pointer ----
    push    16                      ; n = smax = 16
    push    0x55
    push    16
    push    buf
    call    SYM(x86_memset_s)
    add     esp, 16

    cmp     eax, -1                 ; should not fail
    je      .fail_case5
    cmp     eax, buf                ; should return original pointer
    jne     .fail_case5

    ; ---- case 6: verify bytes were actually written ----
    mov     ecx, 16
    mov     esi, buf
.verify_loop:
    cmp     byte [esi], 0x55        ; every byte should be 0x55 from case 5
    jne     .fail_case6
    inc     esi
    dec     ecx
    jnz     .verify_loop

    ; ---- case 7: returned address matches original address exactly ----
    push    8
    push    0xBB
    push    buf_size
    push    buf
    call    SYM(x86_memset_s)
    add     esp, 16

    mov     esi, buf                ; load actual buf address
    cmp     eax, esi                ; returned ptr must equal buf exactly
    jne     .fail_case7

    ; ---- all cases passed ----
    mov     eax, 0
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

.fail:
    pop     esi
    mov     esp, ebp
    pop     ebp
    ret