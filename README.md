# x86util

a minimal x86 string and memory utility library in pure assembly — no dependencies, no OS calls. links anywhere.

## overview

hand written x86 32-bit assembly implementing common string and memory operations from scratch. no external dependencies, no standard library. designed to link into any Win32, ELF32, or MACHO32 target without modification.

every function has a safe `_s` variant with explicit bounds checking and null address validation. the safe variant is always the core implementation — the base function is a thin wrapper that forwards with relaxed defaults.

at runtime the library detects available CPU extensions via `CPUID` and dispatches to the fastest available implementation — from the base x86 path up through SSE2, AVX, and AVX2. all paths produce identical results.

## build
```nasm
nasm -w+all -D WINDOWS -f win32   src/x86util.asm -o x86util.obj
nasm -w+all -D LINUX   -f elf32   src/x86util.asm -o x86util.obj
nasm -w+all -D MACOS   -f macho32 src/x86util.asm -o x86util.obj
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

## calling convention

cdecl — arguments pushed right to left, caller cleans the stack, return value in `eax`.

all functions return `-1` on failure. failure conditions: null address, zero size, size cap exceeded, counter exceeds buffer size.

**exception:** `x86_memcmp_s` and `x86_strcmp_s` return `INT32_MIN` (`0x80000000`) on failure — `-1` is a valid comparison result for these functions and cannot be used as a sentinel.

## design

- safe variant is always the real implementation
- base variant forwards to safe variant with `INT32_MAX` as the default cap
- CPUID queried once on first call, results cached for all subsequent dispatch decisions
- dispatch order: AVX2 → AVX → SSE2 → base x86
- comparison functions return exact byte difference — negative if lhs < rhs, zero if equal, positive if lhs > rhs
- no heap, no globals beyond CPUID cache, no state — pure functions

### optimization coverage

| function | byte loop | dword | SSE2 | AVX | AVX2 |
|---|---|---|---|---|---|
| `x86_memset` | x | x | x | x | x |
| `x86_memcmp` | x | x | x | x | x |
| `x86_memcpy` | x | x | x | x | x |
| `x86_memmove` | x | — | — | — | — |
| `x86_strcmp` | x | — | — | — | — |
| `x86_strcpy` | x | — | — | — | — |
| `x86_strlen` | x | x | x | x| x |

`x86_memmove`, `x86_strcmp`, and `x86_strcpy` operate on a byte loop — memmove requires precise overlap-aware direction control, while strcmp and strcpy must detect null termination mid-scan, both of which make wider register optimization impractical without significant complexity for marginal gain.

## extension paths

| extension | register width | bytes per iteration |
|---|---|---|
| base x86 | 32-bit | 4 |
| SSE2 | 128-bit xmm | 16 |
| AVX | 256-bit ymm | 32 |
| AVX2 | 256-bit ymm + integer ops | 32 |

## structure
```
x86util/
    src/
        x86util.asm
    test/
        test_memset_s.asm
        test_memcpy_s.asm
        test_memmove_s.asm
        test_memcmp_s.asm
        test_strcmp_s.asm
        test_strcpy_s.asm
        test_strlen_s.asm
    README.md
    LICENSE
    .gitignore
    .gitattributes
```

## tests

each function has a dedicated test file covering valid input, null addresses, size violations, boundary conditions, and byte verification. build and link each test against x86util.obj and run — exit code 0 means all cases passed, nonzero indicates the failing case number.
```nasm
nasm -w+all -D WINDOWS -f win32 test/test_memset_s.asm  -o test_memset_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_memcmp_s.asm  -o test_memcmp_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_memcpy_s.asm  -o test_memcpy_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_memmove_s.asm -o test_memmove_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_strcmp_s.asm  -o test_strcmp_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_strcpy_s.asm  -o test_strcpy_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_strlen_s.asm  -o test_strlen_s.obj
```

## target
```
architecture : x86 32-bit
formats      : Win32 COFF, ELF32, MACHO32
assembler    : NASM 2.16+
convention   : cdecl
extensions   : MMX, SSE, SSE2, SSE3, SSSE3, SSE4.1, SSE4.2, AVX, AVX2
dependencies : none
```

## license

this project is released under the **MIT license**. see [LICENSE](LICENSE) for full text.