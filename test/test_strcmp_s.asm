; --------------------------------------------------------
; test_strcmp_s.asm
;   purpose: tests x86_strcmp_s with 10 cases
;   case 1:  equal strings, expect 0
;   case 2:  lhs < rhs at last byte, expect negative
;   case 3:  lhs > rhs at last byte, expect positive
;   case 4:  null lhs, expect INT32_MIN
;   case 5:  null rhs, expect INT32_MIN
;   case 6:  n exceeds lhs size, expect INT32_MIN
;   case 7:  lhs size is zero, expect INT32_MIN
;   case 8:  same address both sides, expect 0
;   case 9:  lhs shorter than rhs, expect negative
;   case 10: mismatch at first byte, expect nonzero
;   build  : nasm -w+all -D WINDOWS -f win32   test_strcmp_s.asm -o test_strcmp_s.obj
;            nasm -w+all -D LINUX   -f elf32   test_strcmp_s.asm -o test_strcmp_s.obj
;            nasm -w+all -D MACOS   -f macho32 test_strcmp_s.asm -o test_strcmp_s.obj
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
extern  SYM(x86_strcmp_s)

section .data
    lhs_equal       db "hello", 0
    lhs_equal_size  equ $ - lhs_equal       ; 6

    rhs_equal       db "hello", 0
    rhs_equal_size  equ $ - rhs_equal       ; 6

    lhs_lesser      db "hello", 0
    lhs_lesser_size equ $ - lhs_lesser      ; 6

    rhs_greater     db "hellz", 0
    rhs_greater_size equ $ - rhs_greater    ; 6

    lhs_greater     db "hellz", 0
    lhs_greater_size equ $ - lhs_greater    ; 6

    rhs_lesser      db "hello", 0
    rhs_lesser_size equ $ - rhs_lesser      ; 6

    lhs_short       db "hi", 0
    lhs_short_size  equ $ - lhs_short       ; 3

    rhs_long        db "high", 0
    rhs_long_size   equ $ - rhs_long        ; 5

    lhs_first       db "zello", 0
    lhs_first_size  equ $ - lhs_first       ; 6

    rhs_first       db "hello", 0
    rhs_first_size  equ $ - rhs_first       ; 6

section .text

SYM(main):
    push    ebp
    mov     ebp, esp

    ; ---- case 1: equal strings, expect 0 ----
    push    6                               ; n = 6 bytes
    push    rhs_equal                       ; rhs address
    push    lhs_equal_size                  ; lhs size = 6
    push    lhs_equal                       ; lhs address
    call    SYM(x86_strcmp_s)
    add     esp, 16

    test    eax, eax                        ; should be 0
    jnz     .fail_case1

    ; ---- case 2: lhs < rhs at last byte, expect negative ----
    push    6
    push    rhs_greater                     ; rhs last byte 'z' > lhs 'o'
    push    lhs_lesser_size
    push    lhs_lesser
    call    SYM(x86_strcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should not be INT32_MIN (error)
    je      .fail_case2
    test    eax, eax
    jns     .fail_case2                     ; should be negative

    ; ---- case 3: lhs > rhs at last byte, expect positive ----
    push    6
    push    rhs_lesser                      ; rhs last byte 'o' < lhs 'z'
    push    lhs_greater_size
    push    lhs_greater
    call    SYM(x86_strcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should not be INT32_MIN (error)
    je      .fail_case3
    test    eax, eax
    jle     .fail_case3                     ; should be positive

    ; ---- case 4: null lhs, expect INT32_MIN ----
    push    6
    push    rhs_equal
    push    lhs_equal_size
    push    0                               ; null lhs
    call    SYM(x86_strcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should be INT32_MIN
    jne     .fail_case4

    ; ---- case 5: null rhs, expect INT32_MIN ----
    push    6
    push    0                               ; null rhs
    push    lhs_equal_size
    push    lhs_equal
    call    SYM(x86_strcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should be INT32_MIN
    jne     .fail_case5

    ; ---- case 6: n exceeds lhs size, expect INT32_MIN ----
    push    32                              ; n = 32, bigger than lhs size
    push    rhs_equal
    push    lhs_equal_size                  ; lhs size = 6
    push    lhs_equal
    call    SYM(x86_strcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should be INT32_MIN
    jne     .fail_case6

    ; ---- case 7: lhs size is zero, expect INT32_MIN ----
    push    6
    push    rhs_equal
    push    0                               ; lhs size = 0
    push    lhs_equal
    call    SYM(x86_strcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should be INT32_MIN
    jne     .fail_case7

    ; ---- case 8: same address both sides, expect 0 ----
    push    6
    push    lhs_equal                       ; rhs == lhs
    push    lhs_equal_size
    push    lhs_equal                       ; lhs == rhs
    call    SYM(x86_strcmp_s)
    add     esp, 16

    test    eax, eax                        ; should be 0
    jnz     .fail_case8

    ; ---- case 9: lhs null terminates before rhs, expect negative ----
    push    3                               ; n = 3, lhs_size cap
    push    rhs_long                        ; rhs = "high"
    push    lhs_short_size                  ; lhs = "hi\0" vs "hig" -> 0x00 < 'g' -> negative
    push    lhs_short
    call    SYM(x86_strcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should not be INT32_MIN (error)
    je      .fail_case9
    test    eax, eax                        ; should be negative
    jns     .fail_case9

    ; ---- case 10: mismatch at first byte, expect nonzero ----
    push    6
    push    rhs_first                       ; rhs = "hello"
    push    lhs_first_size                  ; lhs = "zello"
    push    lhs_first
    call    SYM(x86_strcmp_s)
    add     esp, 16

    cmp     eax, 0x80000000                 ; should not be INT32_MIN (error)
    je      .fail_case10
    test    eax, eax                        ; should be nonzero
    jz      .fail_case10

    ; ---- all cases passed ----
    xor     eax, eax
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
                jmp .fail
.fail_case9:    mov eax, 9
                jmp .fail
.fail_case10:   mov eax, 10

.fail:
    pop     ebp
    ret