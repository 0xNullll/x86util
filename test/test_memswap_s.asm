; --------------------------------------------------------
; test_memswap_s.asm
;   purpose: tests x86_memswap_s with 14 cases
;   case 1:  null lhs, expect -1
;   case 2:  null rhs, expect -1
;   case 3:  zero size, expect -1
;   case 4:  size exceeds UINT32_MAX, expect -1
;   case 5:  zero cap_a, expect -1
;   case 6:  zero cap_b, expect -1
;   case 7:  len > cap_a, expect -1
;   case 8:  len > cap_b, expect -1
;   case 9:  len == cap_a == cap_b (exact fit), expect 0 and correct result
;   case 10: len < cap_a and len < cap_b, expect 0 and correct result
;   case 11: valid large buffer, expect 0 and correct result
;   case 12: lhs == rhs (same pointer), expect 0 and buffer unchanged
;   case 13: unaligned lhs, expect 0 and correct result
;   case 14: tail test (7 bytes), expect 0 and correct result
;   build  : nasm -w+all -D WINDOWS -f win32   test_memswap_s.asm -o test_memswap_s.obj
;            nasm -w+all -D LINUX   -f elf32   test_memswap_s.asm -o test_memswap_s.obj
;            nasm -w+all -D MACOS   -f macho32 test_memswap_s.asm -o test_memswap_s.obj
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

%define UINT32_MAX 0x7FFFFFFF

global  SYM(main)
extern  SYM(x86_memswap_s)

section .data

    ; case 9/10: small buffers
    small_lhs       times 16  db 0xAA
    small_rhs       times 16  db 0x55
    small_size      equ $ - small_rhs          ; 16
    ; expected after swap: lhs = 0x55, rhs = 0xAA

    ; case 11: large buffers
    large_lhs       times 256 db 0xBB
    large_rhs       times 256 db 0x44
    large_size      equ $ - large_rhs          ; 256
    ; expected after swap: lhs = 0x44, rhs = 0xBB

    ; case 12: same pointer — buffer must be unchanged
    same_buf        times 16  db 0xCC
    same_size       equ $ - same_buf            ; 16
    ; expected: 0xCC unchanged

    ; case 13: unaligned lhs (we pass lhs+1)
    align_pad       db 0x00                     ; padding byte to misalign
    align_lhs       times 16  db 0xAA
    align_rhs       times 16  db 0x55
    align_size      equ $ - align_rhs           ; 16
    ; expected after swap: lhs = 0x55, rhs = 0xAA

    ; case 14: tail test — size not multiple of 4
    tail_lhs        times 7   db 0xAA
    tail_rhs        times 7   db 0x55
    tail_size       equ $ - tail_rhs            ; 7
    ; expected after swap: lhs = 0x55, rhs = 0xAA

section .text

SYM(main):
    push    ebp
    mov     ebp, esp
    push    esi
    push    edi

    ; ---- case 1: null lhs, expect -1 ----
    push    small_size                      ; len
    push    small_size                      ; cap_b
    push    small_rhs                       ; rhs
    push    small_size                      ; cap_a
    push    0                               ; null lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, -1
    jne     .fail_case1

    ; ---- case 2: null rhs, expect -1 ----
    push    small_size                      ; len
    push    small_size                      ; cap_b
    push    0                               ; null rhs
    push    small_size                      ; cap_a
    push    small_lhs                       ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, -1
    jne     .fail_case2

    ; ---- case 3: zero size, expect -1 ----
    push    0                               ; zero len
    push    small_size                      ; cap_b
    push    small_rhs                       ; rhs
    push    small_size                      ; cap_a
    push    small_lhs                       ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, -1
    jne     .fail_case3

    ; ---- case 4: size exceeds UINT32_MAX, expect -1 ----
    push    UINT32_MAX + 1                  ; len
    push    small_size                      ; cap_b
    push    small_rhs                       ; rhs
    push    small_size                      ; cap_a
    push    small_lhs                       ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, -1
    jne     .fail_case4

    ; ---- case 5: zero cap_a, expect -1 ----
    push    small_size                      ; len
    push    small_size                      ; cap_b
    push    small_rhs                       ; rhs
    push    0                               ; zero cap_a
    push    small_lhs                       ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, -1
    jne     .fail_case5

    ; ---- case 6: zero cap_b, expect -1 ----
    push    small_size                      ; len
    push    0                               ; zero cap_b
    push    small_rhs                       ; rhs
    push    small_size                      ; cap_a
    push    small_lhs                       ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, -1
    jne     .fail_case6

    ; ---- case 7: len > cap_a, expect -1 ----
    push    small_size                      ; len (16)
    push    small_size                      ; cap_b (16)
    push    small_rhs                       ; rhs
    push    small_size - 1                  ; cap_a (15) — one short
    push    small_lhs                       ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, -1
    jne     .fail_case7

    ; ---- case 8: len > cap_b, expect -1 ----
    push    small_size                      ; len (16)
    push    small_size - 1                  ; cap_b (15) — one short
    push    small_rhs                       ; rhs
    push    small_size                      ; cap_a (16)
    push    small_lhs                       ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, -1
    jne     .fail_case8

    ; ---- case 9: len == cap_a == cap_b (exact fit), expect 0 and swapped ----
    push    small_size                      ; len (16)
    push    small_size                      ; cap_b (16) — exact fit
    push    small_rhs                       ; rhs
    push    small_size                      ; cap_a (16) — exact fit
    push    small_lhs                       ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, 0
    jne     .fail_case9

    mov     ecx, small_size
    mov     esi, small_lhs
.verify_case9_lhs:
    cmp     byte [esi], 0x55                ; lhs should now have rhs values
    jne     .fail_case9
    inc     esi
    dec     ecx
    jnz     .verify_case9_lhs

    mov     ecx, small_size
    mov     esi, small_rhs
.verify_case9_rhs:
    cmp     byte [esi], 0xAA                ; rhs should now have lhs values
    jne     .fail_case9
    inc     esi
    dec     ecx
    jnz     .verify_case9_rhs

    ; ---- case 10: len < cap_a and len < cap_b, expect 0 and swapped ----
    ; XOR only small_size bytes into large buffers
    push    small_size                      ; len (16)
    push    large_size                      ; cap_b (256) — plenty of room
    push    large_rhs                       ; rhs
    push    large_size                      ; cap_a (256) — plenty of room
    push    large_lhs                       ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, 0
    jne     .fail_case10

    mov     ecx, small_size
    mov     esi, large_lhs
.verify_case10_lhs:
    cmp     byte [esi], 0x44                ; lhs should now have rhs values
    jne     .fail_case10
    inc     esi
    dec     ecx
    jnz     .verify_case10_lhs

    mov     ecx, small_size
    mov     esi, large_rhs
.verify_case10_rhs:
    cmp     byte [esi], 0xBB                ; rhs should now have lhs values
    jne     .fail_case10
    inc     esi
    dec     ecx
    jnz     .verify_case10_rhs

    ; ---- case 11: valid large buffer, expect 0 and swapped ----
    ; restore first small_size bytes dirtied by case 10
    mov     ecx, small_size
    mov     edi, large_lhs
.restore_case11_lhs:
    mov     byte [edi], 0xBB
    inc     edi
    dec     ecx
    jnz     .restore_case11_lhs

    mov     ecx, small_size
    mov     edi, large_rhs
.restore_case11_rhs:
    mov     byte [edi], 0x44
    inc     edi
    dec     ecx
    jnz     .restore_case11_rhs

    push    large_size                      ; len
    push    large_size                      ; cap_b
    push    large_rhs                       ; rhs
    push    large_size                      ; cap_a
    push    large_lhs                       ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, 0
    jne     .fail_case11

    mov     ecx, large_size
    mov     esi, large_lhs
.verify_case11_lhs:
    cmp     byte [esi], 0x44
    jne     .fail_case11
    inc     esi
    dec     ecx
    jnz     .verify_case11_lhs

    mov     ecx, large_size
    mov     esi, large_rhs
.verify_case11_rhs:
    cmp     byte [esi], 0xBB
    jne     .fail_case11
    inc     esi
    dec     ecx
    jnz     .verify_case11_rhs

    ; ---- case 12: lhs == rhs (same pointer), expect 0 and buffer unchanged ----
    push    same_size                       ; len
    push    same_size                       ; cap_b
    push    same_buf                        ; rhs == lhs
    push    same_size                       ; cap_a
    push    same_buf                        ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, 0
    jne     .fail_case12

    mov     ecx, same_size
    mov     esi, same_buf
.verify_case12:
    cmp     byte [esi], 0xCC                ; buffer must be unchanged
    jne     .fail_case12
    inc     esi
    dec     ecx
    jnz     .verify_case12

    ; ---- case 13: unaligned lhs (lhs+1), expect 0 and swapped ----
    push    align_size                      ; len
    push    align_size                      ; cap_b
    push    align_rhs                       ; rhs
    push    align_size                      ; cap_a
    push    align_lhs                       ; lhs (naturally misaligned by align_pad)
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, 0
    jne     .fail_case13

    mov     ecx, align_size
    mov     esi, align_lhs
.verify_case13_lhs:
    cmp     byte [esi], 0x55
    jne     .fail_case13
    inc     esi
    dec     ecx
    jnz     .verify_case13_lhs

    mov     ecx, align_size
    mov     esi, align_rhs
.verify_case13_rhs:
    cmp     byte [esi], 0xAA
    jne     .fail_case13
    inc     esi
    dec     ecx
    jnz     .verify_case13_rhs

    ; ---- case 14: tail test (7 bytes), expect 0 and swapped ----
    push    tail_size                       ; len (7)
    push    tail_size                       ; cap_b
    push    tail_rhs                        ; rhs
    push    tail_size                       ; cap_a
    push    tail_lhs                        ; lhs
    call    SYM(x86_memswap_s)
    add     esp, 20

    cmp     eax, 0
    jne     .fail_case14

    mov     ecx, tail_size
    mov     esi, tail_lhs
.verify_case14_lhs:
    cmp     byte [esi], 0x55
    jne     .fail_case14
    inc     esi
    dec     ecx
    jnz     .verify_case14_lhs

    mov     ecx, tail_size
    mov     esi, tail_rhs
.verify_case14_rhs:
    cmp     byte [esi], 0xAA
    jne     .fail_case14
    inc     esi
    dec     ecx
    jnz     .verify_case14_rhs

    ; ---- all cases passed ----
    xor     eax, eax
    pop     edi
    pop     esi
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
                jmp .fail
.fail_case11:   mov eax, 11
                jmp .fail
.fail_case12:   mov eax, 12
                jmp .fail
.fail_case13:   mov eax, 13
                jmp .fail
.fail_case14:   mov eax, 14

.fail:
    pop     edi
    pop     esi
    pop     ebp
    ret