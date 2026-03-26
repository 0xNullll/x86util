; --------------------------------------------------------
; test_strrchr_s.asm
;   purpose: tests x86_strrchr_s with 12 cases
;   case 1:  null ptr, expect -1
;   case 2:  zero length, expect -1
;   case 3:  byte found at first position, expect correct address
;   case 4:  byte found near end, expect correct address
;   case 5:  byte found in middle, expect correct address
;   case 6:  byte not present (no NULL hit), expect -1
;   case 7:  string with early NULL termination, expect last match before NULL or -1
;   case 8:  single byte buffer, match, expect correct address
;   case 9:  single byte buffer, no match, expect -1
;   case 10: unaligned buffer, byte in head, expect correct address
;   case 11: unaligned buffer, byte in body, expect correct address
;   case 12: max length cutoff before match, expect -1
;   build  : nasm -w+all -D WINDOWS -f win32   test_strrchr_s.asm -o test_strrchr_s.obj
;            nasm -w+all -D LINUX   -f elf32   test_strrchr_s.asm -o test_strrchr_s.obj
;            nasm -w+all -D MACOS   -f macho32 test_strrchr_s.asm -o test_strrchr_s.obj
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
extern  SYM(x86_strrchr_s)

section .data

    ; general string buffer (NULL terminated at end)
    general_buf     db 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88
                    db 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00
    general_size    equ $ - general_buf         ; 16

    ; early NULL termination (index 4)
    early_null_buf  db 0x10, 0x20, 0x30, 0x40, 0x00, 0x50, 0x60
    early_null_size equ $ - early_null_buf      ; 7

    ; single byte buffers
    single_match    db 0x42, 0x00
    single_nomatch  db 0x42, 0x00

    ; unaligned buffer
    align_pad       db 0x00
    align_buf       db 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE
                    db 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x00
    align_size      equ $ - align_buf           ; 16

section .text

SYM(main):
    push    ebp
    mov     ebp, esp
    push    esi

    ; ---- case 1: null ptr, expect -1 ----
    push    general_size
    push    0x33
    push    0
    call    SYM(x86_strrchr_s)
    add     esp, 12

    cmp     eax, -1
    jne     .fail_case1

    ; ---- case 2: zero length, expect -1 ----
    push    0
    push    0x33
    push    general_buf
    call    SYM(x86_strrchr_s)
    add     esp, 12

    cmp     eax, -1
    jne     .fail_case2

    ; ---- case 3: byte found at first position ----
    push    general_size
    push    0x11
    push    general_buf
    call    SYM(x86_strrchr_s)
    add     esp, 12

    lea     esi, [general_buf] 
    cmp     eax, esi
    jne     .fail_case3

    ; ---- case 4: byte found near end ----
    push    general_size
    push    0xFF
    push    general_buf
    call    SYM(x86_strrchr_s)
    add     esp, 12

    lea     esi, [general_buf + 14]
    cmp     eax, esi
    jne     .fail_case4

    ; ---- case 5: byte found in middle ----
    push    general_size
    push    0x99
    push    general_buf
    call    SYM(x86_strrchr_s)
    add     esp, 12

    lea     esi, [general_buf + 8]
    cmp     eax, esi
    jne     .fail_case5

    ; ---- case 6: byte not present, expect -1 ----
    push    general_size
    push    0x01
    push    general_buf
    call    SYM(x86_strrchr_s)
    add     esp, 12

    cmp     eax, -1
    jne     .fail_case6

    ; ---- case 7: early NULL termination ----
    push    early_null_size
    push    0x50
    push    early_null_buf
    call    SYM(x86_strrchr_s)
    add     esp, 12

    cmp     eax, -1
    jne     .fail_case7

    ; ---- case 8: single byte buffer, match ----
    push    1
    push    0x42
    push    single_match
    call    SYM(x86_strrchr_s)
    add     esp, 12

    cmp     eax, single_match
    jne     .fail_case8

    ; ---- case 9: single byte buffer, no match ----
    push    1
    push    0xFF
    push    single_nomatch
    call    SYM(x86_strrchr_s)
    add     esp, 12

    cmp     eax, -1
    jne     .fail_case9

    ; ---- case 10: unaligned buffer, byte in head ----
    push    align_size
    push    0xAD
    push    align_buf
    call    SYM(x86_strrchr_s)
    add     esp, 12

    lea     esi, [align_buf + 1]
    cmp     eax, esi
    jne     .fail_case10

    ; ---- case 11: unaligned buffer, byte in body ----
    push    align_size
    push    0xCA
    push    align_buf
    call    SYM(x86_strrchr_s)
    add     esp, 12

    lea     esi, [align_buf + 4]
    cmp     eax, esi
    jne     .fail_case11

    ; ---- case 12: max length cutoff before match ----
    push    4
    push    0x55
    push    general_buf
    call    SYM(x86_strrchr_s)
    add     esp, 12

    cmp     eax, -1
    jne     .fail_case12

    ; ---- all cases passed ----
    xor     eax, eax
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

.fail:
    pop     esi
    pop     ebp
    ret