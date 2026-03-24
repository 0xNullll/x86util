; ============================================================
; x86util.asm
;
;   a minimal x86 string and memory utility library
;   in pure assembly with SIMD — no OS calls. links anywhere.
;
;   target  : x86 32-bit | Win32 COFF / ELF32 / MACHO32 | cdecl
;   author  : 0xNullll (https://github.com/0xNullll)
;   nasm    : 2.16 (Dec 20 2022)
;   build   : nasm -w+all -D WINDOWS -f win32   x86util.asm -o x86util.obj
;             nasm -w+all -D LINUX   -f elf32   x86util.asm -o x86util.obj
;             nasm -w+all -D MACOS   -f macho32 x86util.asm -o x86util.obj
;
;   exports
;     x86_memset    - fill a memory region with a value
;     x86_memset_s  - x86_memset with explicit size cap (safe version)
;     x86_memcmp    - compare two memory regions byte by byte
;     x86_memcmp_s  - x86_memcmp with explicit size cap (safe version)
;     x86_memcpy    - copy a memory region (no overlap)
;     x86_memcpy_s  - x86_memcpy with explicit size cap (safe version | no overlap)
;     x86_memmove   - copy a memory region (overlap safe)
;     x86_memmove_s - x86_memmove with explicit size cap (safe version | overlap safe)
;     x86_strcmp    - compare two strings
;     x86_strcmp_s  - x86_strcmp with explicit size cap (safe version)
;     x86_strcpy    - copy a string into a buffer
;     x86_strcpy_s  - x86_strcpy with explicit size cap (safe version)
;     x86_strlen    - get length of a null terminated string
;     x86_strlen_s  - x86_strlen with explicit size cap (safe version)
;
;   additional exports (functions not yet implemented)
;     x86_bzero       - zero out a memory region
;     x86_bzero_s     - x86_bzero with explicit size cap (safe version)
;     x86_memxor      - XOR two memory regions, store result in first
;     x86_memxor_s    - x86_memxor with explicit size cap (safe version)
;     x86_memswap     - swap two memory regions in place
;     x86_memswap_s   - x86_memswap with explicit size cap (safe version)
;     x86_memrev      - reverse a memory block in place
;     x86_memrev_s    - x86_memrev with explicit size cap (safe version)
;     x86_memchr      - find first occurrence of a byte in memory
;     x86_memchr_s    - x86_memchr with explicit size cap (safe version)
;     x86_strchr      - find first occurrence of a character in string
;     x86_strchr_s    - x86_strchr with explicit size cap (safe version)
;     x86_checksum32  - compute 32-bit checksum over a memory block
;     x86_checksum32_s- x86_checksum32 with explicit size cap (safe version)
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

global SYM(x86_memset_s)
global SYM(x86_memset)
global SYM(x86_memcmp)
global SYM(x86_memcmp_s)
global SYM(x86_memcpy_s)
global SYM(x86_memcpy)
global SYM(x86_memmove_s)
global SYM(x86_memmove)
global SYM(x86_strcmp)
global SYM(x86_strcmp_s)
global SYM(x86_strcpy)
global SYM(x86_strcpy_s)
global SYM(x86_strlen_s)
global SYM(x86_strlen)

%define INT32_MAX 0x7FFFFFFF
%define INT32_MIN 0x80000000

section .text

; --------------------------------------------------------
; x86_memset_s
; --------------------------------------------------------
;   purpose: fills a memory object with a given byte value,
;            with bounds checking and null address validation
;   input:   [ebp+8]  address to the object to fill  (4 bytes)
;            [ebp+12] object size                    (4 bytes)
;            [ebp+16] fill byte                      (4 bytes)
;            [ebp+20] number of bytes to fill        (4 bytes)
;   output:  eax = original object address
;            eax = -1 on failure
;   trashes: ecx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_memset_s):
    push    ebp
    mov     ebp, esp
    push    esi                 ; save callee saved [ebp-4]
    push    edi                 ; save callee saved [ebp-8]
    sub     esp, 8              ; local var [ebp-12] + 4 bytes padding

    mov     esi, [ebp+8]        ; load object address
    mov     eax, [ebp+12]       ; load object size
    mov     ecx, [ebp+20]       ; load counter

    ; check if object size and counter exceeds INT32_MAX
    cmp     eax, INT32_MAX
    ja      .fail
    cmp     ecx, INT32_MAX
    ja      .fail

    ; check if object size is zero
    test    eax, eax
    jz      .fail

    ; check if counter is longer than object size
    cmp     eax, ecx
    jl      .fail

    ; reset eax with the char to set with
    mov     eax, [ebp+16]

    ; check if address is NULL
    test    esi, esi
    jz      .fail

    mov     edi, esi            ; save original address

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
    mov     dword [ebp-12], ecx ; save full count
    and     dword [ebp-12], 3   ; keep bottom 2 bits
    cmp     ecx, 4
    jl      .pre_tail           ; less than 4 bytes left, skip dword loop
    shr     ecx, 2              ; convert to dword count
    imul    eax, 0x01010101     ; broadcast fill byte

; process aligned dwords using broadcast bitmask
.body:
    mov     dword [esi], eax    ; set broadcasted dword
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
    mov     eax, edi            ; return the orginal address

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
; x86_memset
; --------------------------------------------------------
;   purpose: thin wrapper around x86_memset_s with no size cap
;   input:   [ebp+4]  address to the object to fill  (4 bytes)
;            [ebp+8]  fill byte                      (4 bytes)
;            [ebp+12] number of bytes to fill        (4 bytes)
;   output:  eax = original object address
;            eax = -1 on failure
;   trashes: ecx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_memset):
    mov     eax, [esp+4]        ; addr
    mov     ecx, [esp+8]        ; fill byte
    mov     edx, [esp+12]       ; n
    push    edx                 ; n
    push    ecx                 ; fill byte
    push    dword INT32_MAX     ; smax
    push    eax                 ; addr
    call    SYM(x86_memset_s)
    add     esp, 16
    ret

; --------------------------------------------------------
; x86_memcmp_s
; --------------------------------------------------------
;   purpose: compare n bytes of two memory regions,
;            with bounds checking and null address validation
;   input:   [ebp+8]  address of left hand object       (4 bytes)
;            [ebp+12] left hand object size             (4 bytes)
;            [ebp+16] address of right hand object      (4 bytes)
;            [ebp+20] number of bytes to compare        (4 bytes)
;   output:  eax = 0  if regions are equal
;            eax < 0  if lhs byte < rhs byte at first difference
;            eax > 0  if lhs byte > rhs byte at first difference
;            eax = INT32_MIN on failure
;   trashes: ecx, edx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_memcmp_s):
    push    ebp
    mov     ebp, esp
    push    esi                 ; save callee saved [ebp-4]
    push    edi                 ; save callee saved [ebp-8]
    sub     esp, 8              ; local var [ebp-12] + 4 bytes padding

    mov     esi, [ebp+8]        ; load left object address
    mov     eax, [ebp+12]       ; load left object size
    mov     edi, [ebp+16]       ; load right object address
    mov     ecx, [ebp+20]       ; load counter

    ; check if left object size and counter exceeds INT32_MAX
    cmp     eax, INT32_MAX
    ja      .fail
    cmp     ecx, INT32_MAX
    ja      .fail

    ; check if left object size is zero
    test    eax, eax
    jz      .fail

    ; check if counter is longer than left object size
    cmp     eax, ecx
    jl      .fail

    ; check if left and right addresses are NULL
    test    esi, esi
    jz      .fail
    test    edi, edi
    jz      .fail

    ; check if lhs == rhs, pfft nothing to do, both are equal
    cmp     esi, edi
    je      .equal

    cld                         ; make sure direction flag is set to forward

    test    esi, 3
    jz      .body               ; already aligned, skip head entirely

; process unaligned head bytes one at a time
.unaligned_lhs:
    cmpsb                       ; compare [esi] with [edi], advance both
    jnz     .not_equal          ; if ZF=0, mismatch found
    dec     ecx
    jz      .done               ; proccessed the whole counter
    test    esi, 3              ; check if aligned now
    jz      .body
    jmp     .unaligned_lhs

.body:
    mov     dword [ebp-12], ecx ; save full count
    and     dword [ebp-12], 3   ; keep bottom 2 bits = remainder
    cmp     ecx, 4
    jl      .tail               ; less than 4 bytes, skip dword loop
    shr     ecx, 2              ; convert to dword count

    repe    cmpsd               ; compare dword [esi] with [edi]
    jne     .find_byte          ; mismatch in this dword, locate exact byte
    jmp     .tail

.find_byte:
    sub     esi, 4              ; back up full dword
    sub     edi, 4
    mov     ecx, 4              ; scan 4 bytes
    repe    cmpsb               ; find exact differing byte
                                ; esi/edi now one past differing byte
    jmp     .not_equal          ; dec + subtract

.tail:
    mov     ecx, [ebp-12]       ; load remainder byte count
    test    ecx, ecx
    jz      .equal              ; nothing left to compare, all matched
    repe    cmpsb               ; compare remaining bytes [esi] with [edi]
    jne     .not_equal          ; mismatch spotted

.not_equal:
    ; mismatch found, esi/edi point one past differing bytes
    ; back up one to get the differing bytes
    dec     esi
    dec     edi

    movzx   eax, byte [esi]     ; lhs byte
    movzx   edx, byte [edi]     ; rhs byte
    sub     eax, edx            ; lhs - rhs -> negative, zero, positive
    jnz     .done

.equal:
    xor     eax, eax            ; both are equal, return 0

.done:
    lea     esp, [ebp-8]
    pop     edi
    pop     esi
    pop     ebp
    ret

.fail:
    mov     eax, INT32_MIN

    lea     esp, [ebp-8]
    pop     edi
    pop     esi
    pop     ebp
    ret

; --------------------------------------------------------
; x86_memcmp
; --------------------------------------------------------
;   purpose: thin wrapper around x86_memcmp_s with no size cap
;   input:   [ebp+4]  address of left hand object       (4 bytes)
;            [ebp+8]  address of right hand object      (4 bytes)
;            [ebp+12] number of bytes to compare        (4 bytes)
;   output:  eax = 0  if regions are equal
;            eax < 0  if lhs byte < rhs byte at first difference
;            eax > 0  if lhs byte > rhs byte at first difference
;            eax = INT32_MIN on failure
;   trashes: ecx, edx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_memcmp):
    mov     eax, [esp+4]        ; left addr
    mov     ecx, [esp+8]        ; right addr
    mov     edx, [esp+12]       ; n
    push    edx                 ; n
    push    ecx                 ; right addr
    push    dword INT32_MAX     ; smax
    push    eax                 ; left addr
    call    SYM(x86_memcmp_s)
    add     esp, 16
    ret

; --------------------------------------------------------
; x86_memcpy_s
; --------------------------------------------------------
;   purpose: copy n bytes from one memory object to another,
;            with bounds checking and null address validation
;   input:   [ebp+8]  address of destination object     (4 bytes)
;            [ebp+12] destination object size           (4 bytes)
;            [ebp+16] address of source object          (4 bytes)
;            [ebp+20] number of bytes to copy           (4 bytes)
;   output:  eax = original destination object address
;            eax = -1 on failure
;   trashes: ecx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_memcpy_s):
    push    ebp
    mov     ebp, esp
    push    esi                 ; save callee saved [ebp-4]
    push    edi                 ; save callee saved [ebp-8]
    sub     esp, 8              ; local var [ebp-12] + [ebp-16]

    mov     edi, [ebp+8]        ; load dest object address
    mov     eax, [ebp+12]       ; load dest object size
    mov     esi, [ebp+16]       ; load src object address
    mov     ecx, [ebp+20]       ; load counter

    ; check if dest object size and counter exceeds INT32_MAX
    cmp     eax, INT32_MAX
    ja      .fail
    cmp     ecx, INT32_MAX
    ja      .fail

    ; check if dest object size is zero
    test    eax, eax
    jz      .fail

    ; check if counter is longer than dest object size
    cmp     eax, ecx
    jl      .fail

    ; check if dest and src addresses are NULL
    test    edi, edi
    jz      .fail
    test    esi, esi
    jz      .fail

    mov     dword [ebp-16], edi ; save dest original address

    cld                         ; make sure direction flag is set to forward

    test    edi, 3
    jz      .body               ; already aligned, skip head entirely

; process unaligned head bytes one at a time
.unaligned_dst:
    movsb                       ; copy 1 byte [esi] -> [edi], advance both
    dec     ecx
    jz      .done               ; proccessed the whole counter
    test    edi, 3              ; check if aligned now
    jz      .body
    jmp     .unaligned_dst

.body:
    mov     dword [ebp-12], ecx ; save full count
    and     dword [ebp-12], 3   ; keep bottom 2 bits
    cmp     ecx, 4
    jl      .tail               ; less than 4 bytes left, skip dword loop
    shr     ecx, 2              ; convert to dword count

    ; bulk copy aligned dwords
    rep     movsd               ; copy ecx dwords [esi] -> [edi], advances both

.tail:
    mov     ecx, [ebp-12]       ; load remainder byte count
    test    ecx, ecx
    jz      .done               ; nothing left
    rep     movsb               ; copy remaining bytes [esi] -> [edi]

.done:
    mov     eax, [ebp-16]       ; return the orginal dest address

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
; x86_memcpy
; --------------------------------------------------------
;   purpose: thin wrapper around x86_memcpy_s with no size cap
;   input:   [ebp+4]  address of destination object     (4 bytes)
;            [ebp+8]  address of source object          (4 bytes)
;            [ebp+12] number of bytes to copy           (4 bytes)
;   output:  eax = original destination object address
;            eax = -1 on failure
;   trashes: ecx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_memcpy):
    mov     eax, [esp+4]        ; dest addr
    mov     ecx, [esp+8]        ; src addr
    mov     edx, [esp+12]       ; n
    push    edx                 ; n
    push    ecx                 ; src addr
    push    dword INT32_MAX     ; smax
    push    eax                 ; dest addr
    call    SYM(x86_memcpy_s)
    add     esp, 16
    ret

; --------------------------------------------------------
; x86_memmove_s
; --------------------------------------------------------
;   purpose: copy n bytes from one memory object to another,
;            overlap safe, with bounds checking and null
;            address validation
;   input:   [ebp+8]  address of destination object     (4 bytes)
;            [ebp+12] destination object size           (4 bytes)
;            [ebp+16] address of source object          (4 bytes)
;            [ebp+20] number of bytes to copy           (4 bytes)
;   output:  eax = original destination object address
;            eax = -1 on failure
;   trashes: ecx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_memmove_s):
    push    ebp
    mov     ebp, esp
    push    esi                 ; save callee saved [ebp-4]
    push    edi                 ; save callee saved [ebp-8]
    sub     esp, 8              ; local var [ebp-12] + [ebp-16]

    mov     edi, [ebp+8]        ; load dest object address
    mov     eax, [ebp+12]       ; load dest object size
    mov     esi, [ebp+16]       ; load src object address
    mov     ecx, [ebp+20]       ; load counter

    ; check if dest object size and counter exceeds INT32_MAX
    cmp     eax, INT32_MAX
    ja      .fail
    cmp     ecx, INT32_MAX
    ja      .fail

    ; check if dest object size is zero
    test    eax, eax
    jz      .fail

    ; check if counter is longer than dest object size
    cmp     eax, ecx
    jl      .fail

    ; check if dest and src addresses are NULL
    test    edi, edi
    jz      .fail
    test    esi, esi
    jz      .fail

    mov     dword [ebp-16], edi ; save dest original address

    ; check if dst == src, pfft nothing to do
    cmp     edi, esi
    je      .done

    ; check overlap and pick direction
    mov     eax, edi            ; eax = dst
    sub     eax, esi            ; eax = dst - src
    cmp     eax, ecx            ; dst - src < n?
    jb      .backward           ; overlap detected, copy backward

.forward:
    cld                         ; direction flag forward

    test    edi, 3
    jz      .body               ; already aligned, skip head entirely

; process unaligned head bytes one at a time
.unaligned_dst:
    movsb                       ; copy 1 byte [esi] -> [edi], advance both
    dec     ecx
    jz      .done               ; processed the whole counter
    test    edi, 3              ; check if aligned now
    jz      .body
    jmp     .unaligned_dst

.body:
    mov     dword [ebp-12], ecx ; save full count
    and     dword [ebp-12], 3   ; keep bottom 2 bits = remainder
    cmp     ecx, 4
    jl      .tail               ; less than 4 bytes, skip dword loop
    shr     ecx, 2              ; convert to dword count

    ; bulk copy aligned dwords
    rep     movsd               ; copy ecx dwords [esi] -> [edi], advances both

.tail:
    mov     ecx, [ebp-12]       ; load remainder byte count
    test    ecx, ecx
    jz      .done               ; nothing left
    rep     movsb               ; copy remaining bytes [esi] -> [edi]
    jmp     .done

.backward:
    std                         ; direction flag backward

    add     esi, ecx            ; point to last byte of src
    add     edi, ecx            ; point to last byte of dst
    dec     esi
    dec     edi

    ; copy all bytes backward, no dword optimization
    rep     movsb               ; copy ecx bytes [esi] -> [edi], decrements both

    cld                         ; reset direction flag

.done:
    mov     eax, [ebp-16]       ; return the original dest address

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
; x86_memmove
; --------------------------------------------------------
;   purpose: thin wrapper around x86_memmove_s with no size cap
;   input:   [ebp+4]  address of destination object     (4 bytes)
;            [ebp+8]  address of source object          (4 bytes)
;            [ebp+12] number of bytes to copy           (4 bytes)
;   output:  eax = original destination object address
;            eax = -1 on failure
;   trashes: ecx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_memmove):
    mov     eax, [esp+4]        ; dest addr
    mov     ecx, [esp+8]        ; src addr
    mov     edx, [esp+12]       ; n
    push    edx                 ; n
    push    ecx                 ; src addr
    push    dword INT32_MAX     ; smax
    push    eax                 ; dest addr
    call    SYM(x86_memmove_s)
    add     esp, 16
    ret

; --------------------------------------------------------
; x86_strcmp_s
; --------------------------------------------------------
;   purpose: compare n bytes of two strings that are null terminated,
;            with bounds checking and null address validation
;   input:   [ebp+8]  address of left hand string       (4 bytes)
;            [ebp+12] left hand string size             (4 bytes)
;            [ebp+16] address of right hand string      (4 bytes)
;            [ebp+20] number of bytes to compare        (4 bytes)
;   output:  eax = 0  if strings are equal
;            eax < 0  if lhs byte < rhs byte at first difference
;            eax > 0  if lhs byte > rhs byte at first difference
;            eax = INT32_MIN on failure
;   trashes: ecx, edx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_strcmp_s):
    push    ebp
    mov     ebp, esp
    push    esi                 ; save callee saved [ebp-4]
    push    edi                 ; save callee saved [ebp-8]
    sub     esp, 8              ; local var [ebp-12] + 4 bytes padding

    mov     esi, [ebp+8]        ; load left object address
    mov     eax, [ebp+12]       ; load left object size
    mov     edi, [ebp+16]       ; load right object address
    mov     ecx, [ebp+20]       ; load counter

    ; check if left string size and counter exceeds INT32_MAX
    cmp     eax, INT32_MAX
    ja      .fail
    cmp     ecx, INT32_MAX
    ja      .fail

    ; check if dest string size is zero
    test    eax, eax
    jz      .fail

    ; check if counter is longer than left string size
    cmp     eax, ecx
    jl      .fail

    ; check if left and right addresses are NULL
    test    esi, esi
    jz      .fail
    test    edi, edi
    jz      .fail

    ; check if lhs == rhs, pfft nothing to do, both are equal
    cmp     esi, edi
    je      .equal

; compare byte by byte
.loop:
    mov     al, byte [esi]      ; load lhs byte
    mov     dl, byte [edi]      ; load rhs byte
    cmp     al, dl              ; compare
    jne     .not_equal          ; mismatch -> bail
    test    al, al              ; null check — only need lhs
    jz      .equal              ; both null -> equal
    inc     esi
    inc     edi
    dec     ecx
    jnz     .loop               ; cap hit with all matched -> equal

.not_equal:
    movzx   eax, al             ; lhs byte already in al
    movzx   edx, dl             ; rhs byte already in dl
    sub     eax, edx
    jmp     .done

.equal:
    xor     eax, eax

.done:
    lea     esp, [ebp-8]
    pop     edi
    pop     esi
    pop     ebp
    ret

.fail:
    mov     eax, INT32_MIN

    lea     esp, [ebp-8]
    pop     edi
    pop     esi
    pop     ebp
    ret

; --------------------------------------------------------
; x86_strcmp
; --------------------------------------------------------
;   purpose: thin wrapper around x86_strcmp_s with no size cap
;   input:   [ebp+4]  address of left hand string       (4 bytes)
;            [ebp+8]  address of right hand string      (4 bytes)
;            [ebp+12] number of bytes to compare        (4 bytes)
;   output:  eax = 0  if strings are equal
;            eax < 0  if lhs byte < rhs byte at first difference
;            eax > 0  if lhs byte > rhs byte at first difference
;            eax = INT32_MIN on failure
;   trashes: ecx, edx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_strcmp):
    mov     eax, [esp+4]        ; left addr
    mov     ecx, [esp+8]        ; right addr
    mov     edx, [esp+12]       ; n
    push    edx                 ; n
    push    ecx                 ; right addr
    push    dword INT32_MAX     ; smax
    push    eax                 ; left addr
    call    SYM(x86_strcmp_s)
    add     esp, 16
    ret

; --------------------------------------------------------
; x86_strcpy_s
; --------------------------------------------------------
;   purpose: copy n bytes from one memory string to another,
;            with bounds checking and null address validation
;   input:   [ebp+8]  address of destination string     (4 bytes)
;            [ebp+12] destination string size           (4 bytes)
;            [ebp+16] address of source string          (4 bytes)
;            [ebp+20] number of bytes to copy           (4 bytes)
;   output:  eax = original destination string address
;            eax = -1 on failure
;   trashes: ecx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_strcpy_s):
    push    ebp
    mov     ebp, esp
    push    esi                 ; save callee saved [ebp-4]
    push    edi                 ; save callee saved [ebp-8]
    sub     esp, 8              ; local var [ebp-12] + [ebp-16]

    mov     edi, [ebp+8]        ; load dest string address
    mov     eax, [ebp+12]       ; load dest string size
    mov     esi, [ebp+16]       ; load src string address
    mov     ecx, [ebp+20]       ; load counter

    ; check if dest string size and counter exceeds INT32_MAX
    cmp     eax, INT32_MAX
    ja      .fail
    cmp     ecx, INT32_MAX
    ja      .fail

    ; check if dest string size is zero
    test    eax, eax
    jz      .fail

    ; check if counter is longer than dest string size
    cmp     eax, ecx
    jl      .fail

    ; check if dest and src addresses are NULL
    test    edi, edi
    jz      .fail
    test    esi, esi
    jz      .fail

    cld                         ; make sure direction flag is set to forward

    mov     dword [ebp-16], edi ; save dest original address

.loop:
    mov     al, [esi]           ; read source byte
    movsb                       ; copy 1 byte [esi] -> [edi], advance both
    test    al, al              ; null check
    jz      .done
    dec     ecx
    jz      .done               ; proccessed the whole safety cap
    jmp     .loop

.done:
    mov     eax, [ebp-16]       ; return the orginal dest address

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
; x86_strcpy
; --------------------------------------------------------
;   purpose: thin wrapper around x86_strcpy_s with no size cap
;   input:   [ebp+4]  address of destination string     (4 bytes)
;            [ebp+8]  address of source string          (4 bytes)
;            [ebp+12] number of bytes to copy           (4 bytes)
;   output:  eax = original destination string address
;            eax = -1 on failure
;   trashes: ecx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_strcpy):
    mov     eax, [esp+4]        ; dest addr
    mov     ecx, [esp+8]        ; src addr
    mov     edx, [esp+12]       ; n
    push    edx                 ; n
    push    ecx                 ; src addr
    push    dword INT32_MAX     ; smax
    push    eax                 ; dest addr
    call    SYM(x86_strcpy_s)
    add     esp, 16
    ret

; --------------------------------------------------------
; x86_strlen_s
;   purpose: returns the length of a null terminated string
;   input:   [ebp+8]  string buffer address (4 bytes)
;            [ebp+12] max string length     (4 bytes)
;   output:  eax = string length on success
;            eax = -1 on failure (null address, invalid or
;                  exceeded max length without null found)
;   trashes: ecx, edx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_strlen_s):
    push    ebp
    mov     ebp, esp
    push    esi                 ; save callee saved [ebp-4]
    push    edi                 ; save callee saved [ebp-8]
    sub     esp, 8              ; local var [ebp-12] + 4 bytes padding

    mov     esi, [ebp+8]        ; load string buffer address
    mov     ecx, [ebp+12]       ; load max string length

    ; check if max length exceeds INT32_MAX
    cmp     ecx, INT32_MAX
    ja      .fail

    ; check if max length is zero, fallback to INT32_MAX
    test    ecx, ecx
    jnz     .validate_addr
    mov     ecx, INT32_MAX

.validate_addr:
    ; check if address is NULL
    test    esi, esi
    jz      .fail

    mov     edi, esi            ; save original address for length calculation

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
    mov     dword [ebp-12], ecx ; save full count
    and     dword [ebp-12], 3   ; keep bottom 2 bits
    cmp     ecx, 4
    jl      .pre_tail           ; less than 4 bytes left, skip dword loop
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
    jnz     .find_byte          ; null byte detected in this dword

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
.find_byte:
    bsf     eax, eax            ; find lowest set bit
    shr     eax, 3              ; divide by 8 = byte offset within dword
    add     esi, eax            ; advance to null byte position

.done:
    mov     eax, esi
    sub     eax, edi            ; length = current address - original address
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
; x86_strlen
;   purpose: thin wrapper around x86_strlen_s with no size cap
;   input:   [ebp+4]  string buffer address (4 bytes)
;   output:  eax = string length on success
;            eax = -1 on failure (null address, invalid or
;                  exceeded max length without null found)
;   trashes: ecx, edx
;   saves:   esi, edi
; --------------------------------------------------------
SYM(x86_strlen):
    mov     eax, [esp+4]        ; addr
    push    dword INT32_MAX     ; max limit
    push    eax                 ; addr
    call    SYM(x86_strlen_s)
    add     esp, 8
    ret