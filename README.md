# x86util

Tiny x86 utility library in pure assembly for memory and string operations — optimized, OS-independent, linkable anywhere.

---

## Overview

Hand-written x86 32-bit assembly implementing common string and memory operations from scratch.

- No external dependencies, no standard library.
- Designed to link into any **Win32**, **ELF32**, or **MACHO32** target without modification.
- Every function has a safe `_s` variant with **explicit bounds checking** and **null pointer validation**.
- Safe variant is the core implementation; base variant is a thin wrapper forwarding with relaxed defaults.

---

## Dispatch Model

Each exported function is a **public dispatcher**. On first call:

1. CPUID is queried and cached.
2. Dispatcher selects the fastest implementation based on block size and CPU features:

| Condition | Path |
|-----------|------|
| Block % 16 == 0 & SSE2 available | `_sse2` |
| Block % 8 == 0 & MMX available  | `_mmx`  |
| Block % 4 == 0                   | `_dword`|

- All SIMD paths (`_sse2`, `_mmx`) and `_dword` path ultimately **fall back to the byte loop** for any remaining bytes.
- Public function handles **all dispatch logic**; private implementations **do not detect CPU features**.
- SSE2 uses `lddqu` instead of `movdqu` when SSE3 is present for unaligned loads.

---

## Build & Install

### Clone the repository

```bash
git clone https://github.com/0xNullll/x86util
cd x86util
```

### build
```nasm
; Choose target OS: {WINDOWS|LINUX|MACOS}
; Format mapping: WINDOWS -> win32, LINUX -> elf32, MACOS -> macho32
nasm -w+all -D <OS> -f <FORMAT> src/x86util.asm -o x86util.obj
```

link against your project and declare the functions extern. no runtime, no init, no teardown.

## exports

| function | description |
|---|---|
| `x86_memset` | fill a memory region with a byte value |
| `x86_memset_s` | x86_memset with explicit size cap |
| `x86_memcmp` | compare two memory regions byte by byte |
| `x86_memcmp_s` | x86_memcmp with explicit size cap |
| `x86_memcpy` | copy a memory region, no overlap |
| `x86_memcpy_s` | x86_memcpy with explicit size cap |
| `x86_memmove` | copy a memory region, overlap safe |
| `x86_memmove_s` | x86_memmove with explicit size cap |
| `x86_strcmp` | compare two null terminated strings |
| `x86_strcmp_s` | x86_strcmp with explicit size cap |
| `x86_strcpy` | copy a string into a buffer |
| `x86_strcpy_s` | x86_strcpy with explicit size cap |
| `x86_strlen` | get length of a null terminated string |
| `x86_strlen_s` | x86_strlen with explicit size cap |
| `x86_bzero` | zero out a memory region |
| `x86_memxor` | XOR source buffer into dest in place (dest ^= src) |
| `x86_memxor_s` | x86_memxor with explicit size cap |
| `x86_memswap` | swap two memory regions in place |
| `x86_memswap_s` | x86_memswap with explicit size cap |
| `x86_memchr` | find first occurrence of a byte in memory |
| `x86_memrchr` | find last occurrence of a byte in memory |
| `x86_strchr` | find first occurrence of a character in string |
| `x86_strchr_s` | x86_strchr with explicit size cap |
| `x86_strrchr` | find last occurrence of a character in string |
| `x86_strrchr_s` | x86_strrchr with explicit size cap |

## calling convention

cdecl — arguments pushed right to left, caller cleans the stack, return value in `eax`.

all functions return `-1` on failure. failure conditions: null address, zero size, size cap exceeded, counter exceeds buffer size.

**exception:** `x86_memcmp_s` and `x86_strcmp_s` return `INT32_MIN` (`0x80000000`) on failure — `-1` is a valid comparison result for these functions and cannot be used as a sentinel.

## design

- Safe variant is always the real implementation.
- Base variant forwards to safe variant with `NO_CAP` as default cap.  
- CPUID queried once on first call; results cached for all subsequent dispatches.
- Dispatch chooses highest viable SIMD path where block is multiple of register width.
- Comparison functions return exact byte difference: negative if lhs < rhs, zero if equal, positive if lhs > rhs.
- No heap, no globals except CPUID cache, no persistent state.

> **Note:** Optimization beyond SIMD is not yet added. The library layout, including function order and memory layout, may be heavily modified in future updates to accommodate further optimizations.

### optimization coverage

| function | byte loop | dword | MMX | SSE2 |
|---|---|---|---|---|
| `x86_memset` | x | x | planned | planned |
| `x86_memcmp` | x | x | planned | planned |
| `x86_memcpy` | x | x | planned | planned |
| `x86_memmove` | x | x | planned | planned |
| `x86_strcmp` | x | — | — | — |
| `x86_strcpy` | x | — | — | — |
| `x86_strchr` | x | — | — | — |
| `x86_strrchr` | x | — | — | — |
| `x86_strlen` | x | x | planned | planned |
| `x86_bzero` | x | x | planned | planned |
| `x86_memxor` | x | x | planned | planned |
| `x86_memswap` | x | x | planned | planned |
| `x86_memchr` | x | x | planned | planned |
| `x86_memrchr` | x | x | planned | planned |

`x86_strcmp`, `x86_strcpy`, `x86_strchr`, and `x86_strrchr` operate on a byte loop only — all must detect null termination mid-scan, making wider register optimization impractical without significant complexity for marginal gain.

## extension paths

| extension | register width | bytes per iteration | dispatch condition |
|---|---|---|---|
| base x86 (byte) | 8-bit | 1 | fallback / residual tail |
| base x86 (dword) | 32-bit | 4 | block multiple of 4 |
| MMX | 64-bit mm | 8 | block multiple of 8, MMX available |
| SSE2 | 128-bit xmm | 16 | block multiple of 16, SSE2 available |

> the SSE2 path uses `lddqu` instead of `movdqu` for unaligned loads when SSE3 is also present.

## structure
```
x86util/
    src/
        x86util.asm
    test/
        test_bzero.asm
        test_memchr.asm
        test_memcmp_s.asm
        test_memcpy_s.asm
        test_memmove_s.asm
        test_memrchr.asm
        test_memset_s.asm
        test_memswap_s.asm
        test_memxor_s.asm
        test_strchr_s.asm
        test_strcmp_s.asm
        test_strcpy_s.asm
        test_strlen_s.asm
        test_strrchr_s.asm
    README.md
    LICENSE
    .gitignore
    .gitattributes
```

## tests
Each function has dedicated tests covering:
- Valid input
- Null pointers
- Size violations
- Alignment conditions
- Boundary conditions
- Byte-level correctness

### build the library

```nasm
; Choose target OS: {WINDOWS|LINUX|MACOS}
; Format mapping: WINDOWS -> win32, LINUX -> elf32, MACOS -> macho32
nasm -w+all -D <OS> -f <FORMAT> src/x86util.asm -o x86util.obj
```

### build a test

```nasm
nasm -w+all -D <OS> -f <FORMAT> test/<file>.asm -o <file>.obj
```

### link and run

**windows (MSVC link)**
```bat
link /subsystem:console /entry:_main <file>.obj x86util.obj /out:<file>.exe
<file>.exe
echo "exit code $LASTEXITCODE"
```

**windows (MinGW ld)**
```bash
ld -m i386pe --subsystem console -e _main <file>.obj x86util.obj -o <file>.exe
./<file>.exe
echo "exit code: $?"
```

**linux**
```bash
ld -m elf_i386 -e main <file>.obj x86util.obj -o <file>
./<file>
echo "exit code: $?"
```

**macos**
```bash
ld -arch i386 -e _main <file>.obj x86util.obj -o <file>
./<file>
echo "exit code: $?"
```

exit code `0` means all cases passed. nonzero indicates the failing case number.

## target
```
architecture : x86 32-bit
formats      : Win32 COFF, ELF32, MACHO32
assembler    : NASM 2.16+
convention   : cdecl
extensions   : MMX, SSE2, SSE3
dependencies : none
```

## license

this project is released under the **MIT license**. see [LICENSE](LICENSE) for full text.