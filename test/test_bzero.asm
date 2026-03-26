; --------------------------------------------------------
; test_bzero.asm
;   purpose: tests x86_bzero with 6 cases
;   case 1:  null address, expect -1
;   case 2:  zero size, expect -1
;   case 3:  valid small buffer, expect 0 and all bytes zeroed
;   case 4:  valid large buffer, expect 0 and all bytes zeroed
;   case 5:  already zeroed buffer, expect 0 and all bytes zeroed
;   build  : nasm -w+all -D WINDOWS -f win32   test_bzero.asm -o test_bzero.obj
;            nasm -w+all -D LINUX   -f elf32   test_bzero.asm -o test_bzero.obj
;            nasm -w+all -D MACOS   -f macho32 test_bzero.asm -o test_bzero.obj
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
extern  SYM(x86_bzero)

section .data
    small_buf       times 16  db 0xAA       ; 16 bytes prefilled with 0xAA
    small_buf_size  equ $ - small_buf       ; 16

    large_buf       times 256 db 0xBB       ; 256 bytes prefilled with 0xBB
    large_buf_size  equ $ - large_buf       ; 256

    zeroed_buf      times 16  db 0x00       ; already zeroed buffer
    zeroed_buf_size equ $ - zeroed_buf      ; 16

section .text

SYM(main):
    push    ebp
    mov     ebp, esp
    push    edi

    ; ---- case 1: null address, expect -1 ----
    push    small_buf_size
    push    0                               ; null address
    call    SYM(x86_bzero)
    add     esp, 8

    cmp     eax, -1
    jne     .fail_case1

    ; ---- case 2: zero size, expect -1 ----
    push    0                               ; zero size
    push    small_buf
    call    SYM(x86_bzero)
    add     esp, 8

    cmp     eax, -1
    jne     .fail_case2

    ; ---- case 3: valid small buffer, expect 0 and all bytes zeroed ----
    push    small_buf_size
    push    small_buf
    call    SYM(x86_bzero)
    add     esp, 8

    cmp     eax, 0
    jne     .fail_case4

    mov     ecx, small_buf_size
    mov     esi, small_buf
.verify_small:
    cmp     byte [esi], 0
    jne     .fail_case3
    inc     esi
    dec     ecx
    jnz     .verify_small

    ; ---- case 4: valid large buffer, expect 0 and all bytes zeroed ----
    push    large_buf_size
    push    large_buf
    call    SYM(x86_bzero)
    add     esp, 8

    cmp     eax, 0
    jne     .fail_case5

    mov     ecx, large_buf_size
    mov     esi, large_buf
.verify_large:
    cmp     byte [esi], 0
    jne     .fail_case4
    inc     esi
    dec     ecx
    jnz     .verify_large

    ; ---- case 5: already zeroed buffer, expect 0 and all bytes zeroed ----
    push    zeroed_buf_size
    push    zeroed_buf
    call    SYM(x86_bzero)
    add     esp, 8

    cmp     eax, 0
    jne     .fail_case5

    mov     ecx, zeroed_buf_size
    mov     esi, zeroed_buf
.verify_zeroed:
    cmp     byte [esi], 0
    jne     .fail_case5
    inc     esi
    dec     ecx
    jnz     .verify_zeroed

    ; ---- all cases passed ----
    mov     eax, 0
    pop     edi
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

.fail:
    pop     edi
    pop     ebp
    ret