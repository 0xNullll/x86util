; --------------------------------------------------------
; test_memxor_s.asm
;   purpose: tests x86_memxor_s with 13 cases
;   case 1:  null dest, expect -1
;   case 2:  null src, expect -1
;   case 3:  zero size, expect -1
;   case 4:  size exceeds INT32_MAX, expect -1
;   case 5:  zero dest_cap, expect -1
;   case 6:  len > dest_cap, expect -1
;   case 7:  len == dest_cap (exact fit), expect 0 and correct result
;   case 8:  len < dest_cap, expect 0 and correct result
;   case 9:  valid large buffer, expect 0 and correct result
;   case 10: dest == src (self XOR), expect 0 and all zeroed
;   case 11: unaligned dest, expect 0 and correct result
;   case 12: tail test (7 bytes), expect 0 and correct result
;   case 13: zero src (dest unchanged), expect 0 and dest unchanged
;   build  : nasm -w+all -D WINDOWS -f win32   test_memxor_s.asm -o test_memxor_s.obj
;            nasm -w+all -D LINUX   -f elf32   test_memxor_s.asm -o test_memxor_s.obj
;            nasm -w+all -D MACOS   -f macho32 test_memxor_s.asm -o test_memxor_s.obj
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
extern  SYM(x86_memxor_s)

section .data

    ; case 7/8: small buffer — cap larger than len
    small_dst       times 16  db 0xAA
    small_src       times 16  db 0x55
    small_size      equ $ - small_src          ; 16
    ; expected: 0xAA ^ 0x55 = 0xFF per byte

    ; case 9: large buffer
    large_dst       times 256 db 0xBB
    large_src       times 256 db 0x44
    large_size      equ $ - large_src          ; 256
    ; expected: 0xBB ^ 0x44 = 0xFF per byte

    ; case 10: self XOR
    self_buf        times 16  db 0xCC
    self_size       equ $ - self_buf            ; 16
    ; expected: all zero after dest ^= src where dest == src

    ; case 11: unaligned dest (we pass dest+1)
    align_pad       db 0x00                     ; padding byte to misalign
    align_dst       times 16  db 0xAA
    align_src       times 16  db 0x55
    align_size      equ $ - align_src           ; 16
    ; expected: 0xAA ^ 0x55 = 0xFF per byte

    ; case 12: tail test — size not multiple of 4
    tail_dst        times 7   db 0xAA
    tail_src        times 7   db 0x55
    tail_size       equ $ - tail_src            ; 7
    ; expected: 0xAA ^ 0x55 = 0xFF per byte

    ; case 13: zero src — dest must be unchanged
    zero_src        times 16  db 0x00
    zero_dst        times 16  db 0xDD
    zero_size       equ $ - zero_dst            ; 16
    ; expected: 0xDD ^ 0x00 = 0xDD per byte

section .text

SYM(main):
    push    ebp
    mov     ebp, esp
    push    esi
    push    edi

    ; ---- case 1: null dest, expect -1 ----
    push    small_size                      ; len
    push    small_src                       ; src
    push    small_size                      ; dest_cap
    push    0                               ; null dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, -1
    jne     .fail_case1

    ; ---- case 2: null src, expect -1 ----
    push    small_size                      ; len
    push    0                               ; null src
    push    small_size                      ; dest_cap
    push    small_dst                       ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, -1
    jne     .fail_case2

    ; ---- case 3: zero size, expect -1 ----
    push    0                               ; zero len
    push    small_src                       ; src
    push    small_size                      ; dest_cap
    push    small_dst                       ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, -1
    jne     .fail_case3

    ; ---- case 4: size exceeds INT32_MAX, expect -1 ----
    push    INT32_MAX + 1                   ; len
    push    small_src                       ; src
    push    small_size                      ; dest_cap
    push    small_dst                       ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, -1
    jne     .fail_case4

    ; ---- case 5: zero dest_cap, expect -1 ----
    push    small_size                      ; len
    push    small_src                       ; src
    push    0                               ; zero dest_cap
    push    small_dst                       ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, -1
    jne     .fail_case5

    ; ---- case 6: len > dest_cap, expect -1 ----
    push    small_size                      ; len (16)
    push    small_src                       ; src
    push    small_size - 1                  ; dest_cap (15) — one short
    push    small_dst                       ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, -1
    jne     .fail_case6

    ; ---- case 7: len == dest_cap (exact fit), expect 0 and 0xFF per byte ----
    push    small_size                      ; len (16)
    push    small_src                       ; src
    push    small_size                      ; dest_cap (16) — exact fit
    push    small_dst                       ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, 0
    jne     .fail_case7

    mov     ecx, small_size
    mov     esi, small_dst
.verify_case7:
    cmp     byte [esi], 0xFF
    jne     .fail_case7
    inc     esi
    dec     ecx
    jnz     .verify_case7

    ; ---- case 8: len < dest_cap, expect 0 and 0xFF per byte ----
    ; reuse large_dst/src but only XOR small_size bytes into it
    push    small_size                      ; len (16)
    push    large_src                       ; src
    push    large_size                      ; dest_cap (256) — plenty of room
    push    large_dst                       ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, 0
    jne     .fail_case8

    mov     ecx, small_size
    mov     esi, large_dst
.verify_case8:
    cmp     byte [esi], 0xFF
    jne     .fail_case8
    inc     esi
    dec     ecx
    jnz     .verify_case8

    ; ---- case 9: valid large buffer, expect 0 and 0xFF per byte ----
    ; restore first 16 bytes of large_dst back to 0xBB (dirtied by case 8)
    mov     ecx, small_size
    mov     edi, large_dst
.restore_case9:
    mov     byte [edi], 0xBB
    inc     edi
    dec     ecx
    jnz     .restore_case9

    push    large_size                      ; len
    push    large_src                       ; src
    push    large_size                      ; dest_cap
    push    large_dst                       ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, 0
    jne     .fail_case9

    mov     ecx, large_size
    mov     esi, large_dst
.verify_case9:
    cmp     byte [esi], 0xFF
    jne     .fail_case9
    inc     esi
    dec     ecx
    jnz     .verify_case9

    ; ---- case 10: dest == src (self XOR), expect 0 and all zeroed ----
    push    self_size                       ; len
    push    self_buf                        ; src == dest
    push    self_size                       ; dest_cap
    push    self_buf                        ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, 0
    jne     .fail_case10

    mov     ecx, self_size
    mov     esi, self_buf
.verify_case10:
    cmp     byte [esi], 0x00
    jne     .fail_case10
    inc     esi
    dec     ecx
    jnz     .verify_case10

    ; ---- case 11: unaligned dest (dest+1), expect 0 and 0xFF per byte ----
    push    align_size                      ; len
    push    align_src                       ; src
    push    align_size                      ; dest_cap
    push    align_dst                       ; dest (naturally misaligned by align_pad)
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, 0
    jne     .fail_case11

    mov     ecx, align_size
    mov     esi, align_dst
.verify_case11:
    cmp     byte [esi], 0xFF
    jne     .fail_case11
    inc     esi
    dec     ecx
    jnz     .verify_case11

    ; ---- case 12: tail test (7 bytes), expect 0 and 0xFF per byte ----
    push    tail_size                       ; len (7)
    push    tail_src                        ; src
    push    tail_size                       ; dest_cap
    push    tail_dst                        ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, 0
    jne     .fail_case12

    mov     ecx, tail_size
    mov     esi, tail_dst
.verify_case12:
    cmp     byte [esi], 0xFF
    jne     .fail_case12
    inc     esi
    dec     ecx
    jnz     .verify_case12

    ; ---- case 13: zero src, dest must be unchanged (0xDD) ----
    push    zero_size                       ; len
    push    zero_src                        ; src (all zeros)
    push    zero_size                       ; dest_cap
    push    zero_dst                        ; dest
    call    SYM(x86_memxor_s)
    add     esp, 16

    cmp     eax, 0
    jne     .fail_case13

    mov     ecx, zero_size
    mov     esi, zero_dst
.verify_case13:
    cmp     byte [esi], 0xDD
    jne     .fail_case13
    inc     esi
    dec     ecx
    jnz     .verify_case13

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

.fail:
    pop     edi
    pop     esi
    pop     ebp
    ret