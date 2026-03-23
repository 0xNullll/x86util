# x86util

a minimal x86 string and memory utility library in pure assembly — no dependencies, no SIMD, no OS calls. links anywhere.

## overview

hand written x86 32-bit assembly implementing common string and memory operations from scratch. no external dependencies, no standard library, no SIMD extensions — only base registers and base instructions. designed to link into any Win32, ELF32, or MACHO32 target without modification.

every function has a safe `_s` variant with explicit bounds checking and null address validation. the safe variant is always the core implementation — the base function is a thin wrapper that forwards with relaxed defaults.

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
| `asm_strlen` | get length of a null terminated string |
| `asm_strlen_s` | asm_strlen with explicit size cap |
| `asm_memset` | fill a memory region with a byte value |
| `asm_memset_s` | asm_memset with explicit size cap |
| `asm_memcpy` | copy a memory region, no overlap |
| `asm_memcpy_s` | asm_memcpy with explicit size cap |
| `asm_memmove` | copy a memory region, overlap safe |
| `asm_memmove_s` | asm_memmove with explicit size cap |
| `asm_strcmp` | compare two null terminated strings |
| `asm_strcmp_s` | asm_strcmp with explicit size cap |
| `asm_strcpy` | copy a string into a buffer |
| `asm_strcpy_s` | asm_strcpy with explicit size cap |

## calling convention

cdecl — arguments pushed right to left, caller cleans the stack, return value in `eax`.

all functions return `-1` on failure. failure conditions: null address, zero size, size cap exceeded, counter exceeds buffer size.

## design

- safe variant is always the real implementation
- base variant forwards to safe variant with `INT32_MAX` as the default cap
- alignment handled manually — unaligned head processed byte by byte, bulk body processed dword at a time, remaining tail processed byte by byte
- no heap, no globals, no state — pure functions

## structure
```
x86util/
    src/
        x86util.asm
    test/
        test_strlen_s.asm
        test_memset_s.asm
        test_memcpy_s.asm
        test_memmove_s.asm
        test_strcmp_s.asm
        test_strcpy_s.asm
    README.md
    LICENSE
    .gitignore
    .gitattributes
```

## tests

each function has a dedicated test file covering valid input, null addresses, size violations, boundary conditions, and byte verification. build and link each test against x86util.obj and run — exit code 0 means all cases passed, nonzero indicates the failing case number.
```nasm
nasm -w+all -D WINDOWS -f win32 test/test_strlen_s.asm  -o test_strlen_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_memset_s.asm  -o test_memset_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_memcpy_s.asm  -o test_memcpy_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_memmove_s.asm -o test_memmove_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_strcmp_s.asm  -o test_strcmp_s.obj
nasm -w+all -D WINDOWS -f win32 test/test_strcpy_s.asm  -o test_strcpy_s.obj
```

## target
```
architecture : x86 32-bit
formats      : Win32 COFF, ELF32, MACHO32
assembler    : NASM 2.16+
convention   : cdecl
extensions   : none
dependencies : none
```

## License

This project is released under the **MIT license**. See [LICENSE](LICENSE) for full text.