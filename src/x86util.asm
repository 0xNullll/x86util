; ============================================================
; x86util.asm
;
;   a minimal x86 utility library using only base registers,
;   no SIMD extensions, no external dependencies
;
;   target  : x86 32-bit | Win32 COFF / ELF32 / MACHO32 | cdecl
;   author  : 0xNullll (https://github.com/0xNullll)
;   nasm    : 2.16 (Dec 20 2022)
;   build   : nasm -w+all -D WINDOWS -f win32   x86util.asm -o x86util.obj
;             nasm -w+all -D LINUX   -f elf32   x86util.asm -o x86util.obj
;             nasm -w+all -D MACOS   -f macho32 x86util.asm -o x86util.obj
;
;   exports
;     asm_strlen    - get length of a null terminated string
;     asm_strlen_s  - get length with max_len limit (safe version)
;     asm_memset    - fill a memory region with a value
;     asm_memcpy    - copy a memory region (no overlap)
;     asm_memmove   - copy a memory region (overlap safe)
;     asm_strcmp    - compare two strings
;     asm_strcpy    - copy a string into a buffer
; ============================================================

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

global SYM(asm_strlen_s)
global SYM(asm_strlen)

%define INT32_MAX 0x7FFFFFFF

section .text

; --------------------------------------------------------
; asm_strlen_s
;   purpose: returns the length of a null terminated string
;   input:   [ebp+8]  string buffer pointer (4 bytes)
;            [ebp+12] max string length     (4 bytes)
;   output:  eax = string length on success
;            eax = -1 on failure (null pointer, invalid or
;                  exceeded max length without null found)
;   trashes: ecx, edx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(asm_strlen_s):
    push ebp
    mov  ebp, esp
    push esi                ; save callee saved [ebp-4]
    push edi                ; save callee saved [ebp-8]
    sub  esp, 8             ; local variables [ebp-12] and [ebp-16]

    mov esi, [ebp+8]        ; load string buffer pointer
    mov ecx, [ebp+12]       ; load max string length

    ; check if max length exceeds INT32_MAX
    cmp  ecx, INT32_MAX
    ja   .fail

    ; check if max length is zero, fallback to INT32_MAX
    test ecx, ecx
    jnz  .validate_ptr
    mov  ecx, INT32_MAX

.validate_ptr:
    ; check if pointer is NULL
    test esi, esi
    jz   .fail

    mov  edi, esi           ; save original pointer for length calculation

    ; process unaligned head bytes one at a time
.unaligned:
    cmp  byte [esi], 0      ; check for null
    je   .done
    inc  esi
    dec  ecx
    jz   .fail              ; hit max_len, no null found
    test esi, 3             ; check if aligned now
    jz   .pre_body
    jmp  .unaligned

.pre_body:
    cmp  ecx, 4
    jl   .pre_tail          ; less than 4 bytes left, skip dword loop
    mov  [ebp-12], ecx      ; save remainder before shift
    and  dword [ebp-12], 3  ; keep bottom 2 bits = remainder
    shr  ecx, 2             ; convert to dword count

    ; process aligned dwords using bitmask null detection
.body:
    mov  eax, dword [esi]   ; load dword
    mov  edx, eax           ; copy for subtraction
    not  eax                ; ~val
    sub  edx, 0x01010101    ; val - 0x01010101
    and  eax, edx           ; combine
    and  eax, 0x80808080    ; isolate high bits
    test eax, eax
    jnz  .found             ; null byte detected in this dword

    add  esi, 4             ; advance pointer
    dec  ecx                ; decrement dword counter
    jnz  .body

    ; process remaining tail bytes one at a time
.pre_tail:
    mov  ecx, [ebp-12]      ; load remainder byte count

.tail:
    test ecx, ecx
    jz   .fail
    cmp  byte [esi], 0
    je   .done
    inc  esi
    dec  ecx
    jmp  .tail

    ; null found in dword, locate exact byte position
.found:
    bsf  eax, eax           ; find lowest set bit
    shr  eax, 3             ; divide by 8 = byte offset within dword
    add  esi, eax           ; advance to null byte position

.done:
    mov     eax, esi
    sub     eax, edi        ; length = current pointer - original pointer
    lea     esp, [ebp-8]
    pop     edi
    pop     esi
    pop     ebp
    ret

.fail:
    mov     eax, -1
    lea     esp, [ebp-8]
    pop     edi
    pop     esi
    pop     ebp
    ret

; --------------------------------------------------------
; asm_strlen
;   purpose: thin wrapper around asm_strlen_s with no limit
;   input:   [ebp+8]  string buffer pointer (4 bytes)
;   output:  eax = string length on success
;            eax = -1 on failure (null pointer)
;   trashes: ecx, edx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(asm_strlen):
    push  dword INT32_MAX       ; hardcode max limit
    push  dword [esp+8]         ; forward the pointer arg
    call  SYM(asm_strlen_s)     ; call safe version
    add   esp, 8
    ret