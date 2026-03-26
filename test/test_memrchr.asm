; --------------------------------------------------------
; test_memrchr.asm
;   purpose: tests x86_memrchr with 12 cases
;   case 1:  null ptr, expect -1
;   case 2:  zero length, expect -1
;   case 3:  byte found at last position, expect correct address
;   case 4:  byte found at first position, expect correct address
;   case 5:  byte found in middle, expect correct address
;   case 6:  byte not present, expect -1
;   case 7:  all bytes match (last should be returned), expect correct address
;   case 8:  single byte buffer, match, expect correct address
;   case 9:  single byte buffer, no match, expect -1
;   case 10: unaligned buffer, byte in unaligned tail, expect correct address
;   case 11: unaligned buffer, byte in dword body, expect correct address
;   case 12: tail test (len not multiple of 4), byte in tail, expect correct address
;   build  : nasm -w+all -D WINDOWS -f win32   test_memrchr.asm -o test_memrchr.obj
;            nasm -w+all -D LINUX   -f elf32   test_memrchr.asm -o test_memrchr.obj
;            nasm -w+all -D MACOS   -f macho32 test_memrchr.asm -o test_memrchr.obj
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
extern  SYM(x86_memrchr)

section .data

    ; case 3/4/5/6/7: general buffer
    ;   0x11 0x22 0x33 0x44 0x55 0x66 0x77 0x88 0x99 0xAA 0xBB 0xCC 0xDD 0xEE 0xFF 0x11
    general_buf     db 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88
                    db 0x99, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x11
    general_size    equ $ - general_buf         ; 16
    ; note: 0x11 appears at index 0 and index 15 — memrchr must return index 15

    ; case 7: all same byte
    all_same_buf    times 16 db 0xAB
    all_same_size   equ $ - all_same_buf        ; 16
    ; expected: last byte returned (all_same_buf + 15)

    ; case 8/9: single byte buffers
    single_match    db 0x42
    single_nomatch  db 0x42

    ; case 10/11: unaligned buffer (1 pad byte to misalign)
    align_pad       db 0x00
    align_buf       db 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xBE
                    db 0xDE, 0xAD, 0xBE, 0xEF, 0xCA, 0xFE, 0xBA, 0xAD
    align_size      equ $ - align_buf           ; 16
    ; note: 0xAD appears at index 1 and index 15 — memrchr must return index 15

    ; case 12: tail test — length not a multiple of 4
    tail_buf        db 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x01
    tail_size       equ $ - tail_buf            ; 7
    ; note: 0x01 appears at index 0 and index 6 — memrchr must return index 6

section .text

SYM(main):
    push    ebp
    mov     ebp, esp
    push    esi

    ; ---- case 1: null ptr, expect -1 ----
    push    general_size                    ; len
    push    0x33                            ; byte to find
    push    0                               ; null ptr
    call    SYM(x86_memrchr)
    add     esp, 12

    cmp     eax, -1
    jne     .fail_case1

    ; ---- case 2: zero length, expect -1 ----
    push    0                               ; zero len
    push    0x33                            ; byte to find
    push    general_buf                     ; ptr
    call    SYM(x86_memrchr)
    add     esp, 12

    cmp     eax, -1
    jne     .fail_case2

    ; ---- case 3: byte found at last position, expect correct address ----
    ;   0x11 is at both index 0 and index 15, memrchr must return index 15
    push    general_size                    ; len
    push    0x11                            ; last byte in buffer
    push    general_buf                     ; ptr
    call    SYM(x86_memrchr)
    add     esp, 12

    lea     esi, [general_buf + general_size - 1]
    cmp     eax, esi
    jne     .fail_case3

    ; ---- case 4: byte found at first position only, expect correct address ----
    push    general_size                    ; len
    push    0x22                            ; byte only at index 1
    push    general_buf                     ; ptr
    call    SYM(x86_memrchr)
    add     esp, 12

    lea     esi, [general_buf + 1]
    cmp     eax, esi
    jne     .fail_case4

    ; ---- case 5: byte found in middle, expect correct address ----
    push    general_size                    ; len
    push    0x99                            ; byte at index 8
    push    general_buf                     ; ptr
    call    SYM(x86_memrchr)
    add     esp, 12

    lea     esi, [general_buf + 8]
    cmp     eax, esi
    jne     .fail_case5

    ; ---- case 6: byte not present, expect -1 ----
    push    general_size                    ; len
    push    0x00                            ; not in buffer
    push    general_buf                     ; ptr
    call    SYM(x86_memrchr)
    add     esp, 12

    cmp     eax, -1
    jne     .fail_case6

    ; ---- case 7: all bytes match, last should be returned ----
    push    all_same_size                   ; len
    push    0xAB                            ; every byte is 0xAB
    push    all_same_buf                    ; ptr
    call    SYM(x86_memrchr)
    add     esp, 12

    lea     esi, [all_same_buf + all_same_size - 1]
    cmp     eax, esi
    jne     .fail_case7

    ; ---- case 8: single byte buffer, match, expect correct address ----
    push    1                               ; len
    push    0x42                            ; matches single_match
    push    single_match                    ; ptr
    call    SYM(x86_memrchr)
    add     esp, 12

    cmp     eax, single_match
    jne     .fail_case8

    ; ---- case 9: single byte buffer, no match, expect -1 ----
    push    1                               ; len
    push    0xFF                            ; not in single_nomatch
    push    single_nomatch                  ; ptr
    call    SYM(x86_memrchr)
    add     esp, 12

    cmp     eax, -1
    jne     .fail_case9

    ; ---- case 10: unaligned buffer, byte in unaligned tail ----
    ;   0xAD appears at index 1 and index 15 — memrchr must return index 15
    ;   index 15 lands in the unaligned tail when scanning in reverse
    push    align_size                      ; len
    push    0xAD                            ; byte at index 1 and 15
    push    align_buf                       ; ptr (misaligned)
    call    SYM(x86_memrchr)
    add     esp, 12

    lea     esi, [align_buf + 15]
    cmp     eax, esi
    jne     .fail_case10

    ; ---- case 11: unaligned buffer, byte in dword body ----
    ;   0xCA is at index 4 and index 12 — memrchr must return index 12
    push    align_size                      ; len
    push    0xCA                            ; byte at index 4 and 12
    push    align_buf                       ; ptr (misaligned)
    call    SYM(x86_memrchr)
    add     esp, 12

    lea     esi, [align_buf + 12]
    cmp     eax, esi
    jne     .fail_case11

    ; ---- case 12: tail test (7 bytes), byte in tail ----
    ;   0x01 appears at index 0 and index 6 — memrchr must return index 6
    push    tail_size                       ; len (7)
    push    0x01                            ; byte at index 0 and 6
    push    tail_buf                        ; ptr
    call    SYM(x86_memrchr)
    add     esp, 12

    lea     esi, [tail_buf + 6]
    cmp     eax, esi
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