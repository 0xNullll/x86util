; --------------------------------------------------------
; test_memcmp_s.asm
;   purpose: tests x86_memcmp_s with 9 cases
;   case 1:  equal regions, expect 0
;   case 2:  lhs < rhs at first diff, expect negative
;   case 3:  lhs > rhs at first diff, expect positive
;   case 4:  null lhs, expect 0x80000000
;   case 5:  null rhs, expect 0x80000000
;   case 6:  n exceeds lhs size, expect 0x80000000
;   case 7:  lhs size is zero, expect 0x80000000
;   case 8:  same address both sides, expect 0
;   case 9:  mismatch at last byte, expect nonzero
;   build  : nasm -w+all -D WINDOWS -f win32   test_memcmp_s.asm -o test_memcmp_s.obj
;            nasm -w+all -D LINUX   -f elf32   test_memcmp_s.asm -o test_memcmp_s.obj
;            nasm -w+all -D MACOS   -f macho32 test_memcmp_s.asm -o test_memcmp_s.obj
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
extern  SYM(x86_memcmp_s)

section .data
    lhs             db 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08
    lhs_size        equ $ - lhs             ; 8

    rhs_equal       db 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08
    rhs_equal_size  equ $ - rhs_equal       ; 8

    rhs_greater     db 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0xFF
    rhs_greater_size equ $ - rhs_greater    ; 8

    rhs_lesser      db 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x01
    rhs_lesser_size equ $ - rhs_lesser      ; 8

    rhs_last        db 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x09
    rhs_last_size   equ $ - rhs_last        ; 8

section .text

SYM(main):
    push    ebp
    mov     ebp, esp

    ; ---- case 1: equal regions, expect 0 ----
    push    8                               ; n = 8 bytes
    push    rhs_equal                       ; rhs address
    push    lhs_size                        ; lhs size = 8
    push    lhs                             ; lhs address
    call    SYM(x86_memcmp_s)
    add     esp, 16

    test    eax, eax                        ; should be 0
    jnz     .fail_case1

    ; ---- case 2: lhs < rhs at last byte, expect negative ----
    push    8
    push    rhs_greater                     ; rhs last byte 0xFF > lhs 0x08
    push    lhs_size
    push    lhs
    call    SYM(x86_memcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should not be INT32_MIN  (error)
    je      .fail_case2
    test    eax, eax
    jns     .fail_case2                     ; should be negative

    ; ---- case 3: lhs > rhs at last byte, expect positive ----
    push    8
    push    rhs_lesser                      ; rhs last byte 0x01 < lhs 0x08
    push    lhs_size
    push    lhs
    call    SYM(x86_memcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should not be INT32_MIN  (error)
    je      .fail_case3
    test    eax, eax
    jle     .fail_case3                     ; should be positive

    ; ---- case 4: null lhs, expect INT32_MIN  ----
    push    8
    push    rhs_equal
    push    lhs_size
    push    0                               ; null lhs
    call    SYM(x86_memcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should be INT32_MIN 
    jne     .fail_case4

    ; ---- case 5: null rhs, expect INT32_MIN  ----
    push    8
    push    0                               ; null rhs
    push    lhs_size
    push    lhs
    call    SYM(x86_memcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should be INT32_MIN 
    jne     .fail_case5

    ; ---- case 6: n exceeds lhs size, expect INT32_MIN  ----
    push    32                              ; n = 32, bigger than lhs size
    push    rhs_equal
    push    lhs_size                        ; lhs size = 8
    push    lhs
    call    SYM(x86_memcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should be INT32_MIN 
    jne     .fail_case6

    ; ---- case 7: lhs size is zero, expect INT32_MIN  ----
    push    8
    push    rhs_equal
    push    0                               ; lhs size = 0
    push    lhs
    call    SYM(x86_memcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should be INT32_MIN 
    jne     .fail_case7

    ; ---- case 8: same address both sides, expect 0 ----
    push    8
    push    lhs                             ; rhs == lhs
    push    lhs_size
    push    lhs                             ; lhs == rhs
    call    SYM(x86_memcmp_s)
    add     esp, 16

    test    eax, eax                        ; should be 0
    jnz     .fail_case8

    ; ---- case 9: mismatch at last byte only, expect nonzero ----
    push    8
    push    rhs_last                        ; differs only at byte 8 (0x09 vs 0x08)
    push    lhs_size
    push    lhs
    call    SYM(x86_memcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should not be error
    je      .fail_case9
    test    eax, eax                        ; should be nonzero
    jz      .fail_case9

    ; ---- all cases passed ----
    xor     eax, eax
    mov     esp, ebp
    pop     ebp
    ret

.fail_case1:
    mov     eax, 1
    mov     esp, ebp
    pop     ebp
    ret

.fail_case2:
    mov     eax, 2
    mov     esp, ebp
    pop     ebp
    ret

.fail_case3:
    mov     eax, 3
    mov     esp, ebp
    pop     ebp
    ret

.fail_case4:
    mov     eax, 4
    mov     esp, ebp
    pop     ebp
    ret

.fail_case5:
    mov     eax, 5
    mov     esp, ebp
    pop     ebp
    ret

.fail_case6:
    mov     eax, 6
    mov     esp, ebp
    pop     ebp
    ret

.fail_case7:
    mov     eax, 7
    mov     esp, ebp
    pop     ebp
    ret

.fail_case8:
    mov     eax, 8
    mov     esp, ebp
    pop     ebp
    ret

.fail_case9:
    mov     eax, 9
    mov     esp, ebp
    pop     ebp
    ret