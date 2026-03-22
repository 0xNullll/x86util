; --------------------------------------------------------
; test_strlen.asm
;   purpose: tests asm_strlen_s with 3 cases
;   case 1:  valid string, expect correct length
;   case 2:  empty string, expect 0
;   case 3:  max_len smaller than string, expect -1
;   build  : nasm -w+all -D WINDOWS -f win32   test_strlen.asm -o test_strlen.obj
;            nasm -w+all -D LINUX   -f elf32   test_strlen.asm -o test_strlen.obj
;            nasm -w+all -D MACOS   -f macho32 test_strlen.asm -o test_strlen.obj
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
extern SYM(asm_strlen_s)

section .data
    str_hello   db "hello", 0
    str_empty   db 0
    str_long    db "hello world", 0

    str_hello_len   equ $ - str_hello - 1       ; 5
    str_empty_len   equ $ - str_empty - 1       ; 0
    str_long_len    equ $ - str_long  - 1       ; 11

section .text

SYM(main):
    push ebp
    mov  ebp, esp

    ; ---- case 1: valid string "hello" with correct max ----
    push 10                         ; max_len bigger than string
    push str_hello                  ; pointer
    call SYM(asm_strlen_s)
    add  esp, 8

    cmp  eax, str_hello_len         ; should be 5
    jne  .fail_case1

    ; ---- case 2: empty string ----
    push 10
    push str_empty
    call SYM(asm_strlen_s)
    add  esp, 8

    cmp  eax, str_empty_len         ; should be 0
    jne  .fail_case2

    ; ---- case 3: max_len smaller than actual string ----
    push 3                          ; max_len smaller than "hello world"
    push str_long
    call SYM(asm_strlen_s)
    add  esp, 8

    cmp  eax, -1                    ; should be -1
    jne  .fail_case3

    ; ---- all cases passed ----
    mov  eax, 0
    mov  esp, ebp
    pop  ebp
    ret

.fail_case1:
    mov  eax, 1
    mov  esp, ebp
    pop  ebp
    ret

.fail_case2:
    mov  eax, 2
    mov  esp, ebp
    pop  ebp
    ret

.fail_case3:
    mov  eax, 3
    mov  esp, ebp
    pop  ebp
    ret