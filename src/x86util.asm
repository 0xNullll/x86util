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
;     asm_strlen_s  - asm_strlen with with size cap (safe version)
;     asm_memset    - fill a memory region with a value
;     asm_memset_s  - asm_memset with size cap (safe version)
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
global SYM(asm_memset_s)
global SYM(asm_memset)

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
    push    ebp
    mov     ebp, esp
    push    esi                 ; save callee saved [ebp-4]
    push    edi                 ; save callee saved [ebp-8]
    sub     esp, 8              ; local var [ebp-12] + 4 bytes padding

    mov     esi, [ebp+8]        ; load string buffer pointer
    mov     ecx, [ebp+12]       ; load max string length

    ; check if max length exceeds INT32_MAX
    cmp     ecx, INT32_MAX
    ja      .fail

    ; check if max length is zero, fallback to INT32_MAX
    test    ecx, ecx
    jnz     .validate_ptr
    mov     ecx, INT32_MAX

.validate_ptr:
    ; check if pointer is NULL
    test    esi, esi
    jz      .fail

    mov     edi, esi            ; save original pointer for length calculation

    test    esi, 3
    jz      .pre_body           ; already aligned, skip head entirely

    ; process unaligned head bytes one at a time
.unaligned:
    cmp     byte [esi], 0       ; check for null
    je      .done
    inc     esi
    dec     ecx
    jz      .fail               ; hit max_len, no null found
    test    esi, 3              ; check if aligned now
    jz      .pre_body
    jmp     .unaligned

.pre_body:
    mov     dword [ebp-12], ecx ; save full count first
    cmp     ecx, 4
    jl      .pre_tail           ; less than 4 bytes left, skip dword loop
    and     dword [ebp-12], 3   ; keep bottom 2 bits = remainder
    shr     ecx, 2              ; convert to dword count

    ; process aligned dwords using bitmask null detection
.body:
    mov     eax, dword [esi]    ; load dword
    mov     edx, eax            ; copy for subtraction
    not     eax                 ; ~val
    sub     edx, 0x01010101     ; val - 0x01010101
    and     eax, edx            ; combine
    and     eax, 0x80808080     ; isolate high bits
    test    eax, eax
    jnz     .found              ; null byte detected in this dword

    add     esi, 4
    dec     ecx
    jnz     .body

    ; process remaining tail bytes one at a time
.pre_tail:
    mov     ecx, [ebp-12]       ; load remainder byte count

.tail:
    test    ecx, ecx
    jz      .fail
    cmp     byte [esi], 0
    je      .done
    inc     esi
    dec     ecx
    jmp     .tail

    ; null found in dword, locate exact byte position
.found:
    bsf     eax, eax            ; find lowest set bit
    shr     eax, 3              ; divide by 8 = byte offset within dword
    add     esi, eax            ; advance to null byte position

.done:
    mov     eax, esi
    sub     eax, edi            ; length = current pointer - original pointer
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
;            eax = -1 on failure (null pointer, invalid or
;                  exceeded max length without null found)
;   trashes: ecx, edx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(asm_strlen):
    mov     eax, [esp+4]        ; ptr
    push    dword INT32_MAX     ; max limit
    push    eax                 ; ptr
    call    SYM(asm_strlen_s)
    add     esp, 8
    ret

; --------------------------------------------------------
; asm_memset_s
; --------------------------------------------------------
;   purpose: fills a memory object with a given byte value,
;            with bounds checking and null pointer validation
;   input:   [ebp+8]  address to the object to fill  (4 bytes)
;            [ebp+12] object size                    (4 bytes)
;            [ebp+16] fill byte                      (4 bytes)
;            [ebp+20] number of bytes to fill        (4 bytes)
;   output:  eax = original object address
;            eax = -1 on failure
;   trashes: ecx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(asm_memset_s):
    push    ebp
    mov     ebp, esp
    push    esi                 ; save callee saved [ebp-4]
    push    edi                 ; save callee saved [ebp-8]
    sub     esp, 8              ; local var [ebp-12] + 4 bytes padding

    mov     esi, [ebp+8]        ; load object pointer
    mov     eax, [ebp+12]       ; load object size
    mov     ecx, [ebp+20]       ; load counter

    ; check if string length and counter exceeds INT32_MAX
    cmp     eax, INT32_MAX
    ja      .fail
    cmp     ecx, INT32_MAX
    ja      .fail

    ; check if string length is zero
    test    eax, eax
    jz      .fail

    ; check if counter is longer than the string length
    cmp     eax, ecx
    jl      .fail

    ; reset eax with the char to set with
    mov     eax, [ebp+16]

    ; check if pointer is NULL
    test    esi, esi
    jz      .fail

    mov     edi, esi            ; save original pointer

    test    esi, 3
    jz      .pre_body           ; already aligned, skip head entirely

    ; process unaligned head bytes one at a time
.unaligned:
    mov     byte [esi], al
    inc     esi
    dec     ecx
    jz      .done               ; proccessed the whole counter
    test    esi, 3              ; check if aligned now
    jz      .pre_body
    jmp     .unaligned

.pre_body:
    mov     dword [ebp-12], ecx ; save full count first
    cmp     ecx, 4
    jl      .pre_tail           ; less than 4 bytes left, skip dword loop
    and     dword [ebp-12], 3   ; keep bottom 2 bits = remainder
    shr     ecx, 2              ; convert to dword count
    imul    eax, 0x01010101     ; broadcast fill byte

    ; process aligned dwords using broadcast bitmask
.body:
    mov     dword [esi], eax    ; set broadcasted byte
    add     esi, 4
    dec     ecx
    jnz     .body

    ; process remaining tail bytes one at a time
.pre_tail:
    mov     ecx, [ebp-12]       ; load remainder byte count

.tail:
    test    ecx, ecx
    jz      .done
    mov     byte [esi], al
    inc     esi
    dec     ecx
    jmp     .tail

.done:
    mov     eax, edi            ; return the orginal pointer

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
; asm_memset
; --------------------------------------------------------
;   purpose: fills a memory object with a given byte value
;            and null pointer validation
;   input:   [ebp+8]  address to the object to fill  (4 bytes)
;            [ebp+12] fill byte                      (4 bytes)
;            [ebp+16] number of bytes to fill        (4 bytes)
;   output:  eax = original object address
;            eax = -1 on failure
;   trashes: ecx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(asm_memset):
    mov     eax, [esp+4]        ; ptr
    mov     ecx, [esp+8]        ; fill byte
    mov     edx, [esp+12]       ; n
    push    edx                 ; n
    push    ecx                 ; fill byte
    push    dword INT32_MAX     ; smax
    push    eax                 ; ptr
    call    SYM(asm_memset_s)
    add     esp, 16
    ret