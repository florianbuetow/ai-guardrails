// ARM64 macOS ABI scaffolding.
//
// These macros carry the guarantees that a textual linter cannot prove:
// balanced prologue/epilogue construction and 16-byte stack alignment are
// properties of the macro expansion, not of a checker's guesswork.
//
// Frame allocation MUST go through FRAME_PUSH / FRAME_POP. Raw `sp`
// arithmetic outside this file is rejected by scripts/verify-abi.sh.

#ifndef ABI_INC
#define ABI_INC

// Open an exported function. Emits the global symbol, instruction
// alignment and CFI so lldb and crash reports can unwind through it.
.macro FUNC name
    .globl \name
    .p2align 2
\name:
    .cfi_startproc
.endm

// Close an exported function opened with FUNC.
.macro ENDFUNC name
    .cfi_endproc
.endm

// Open a file-local helper. Same unwind discipline as FUNC, but the
// symbol stays out of the global symbol table.
.macro LOCAL_FUNC name
    .p2align 2
\name:
    .cfi_startproc
.endm

// Close a helper opened with LOCAL_FUNC.
.macro LOCAL_ENDFUNC name
    .cfi_endproc
.endm

// Save the frame pointer and link register, then allocate \size bytes of
// locals rounded up to a multiple of 16. The rounding happens at assembly
// time, so an unaligned request cannot reach the stack pointer.
.macro FRAME_PUSH size=0
    stp x29, x30, [sp, #-16]!
    .cfi_def_cfa_offset 16
    mov x29, sp
    .if \size > 0
    sub sp, sp, #(((\size) + 15) & ~15)
    .endif
.endm

// Release a frame allocated by FRAME_PUSH. The size must match.
.macro FRAME_POP size=0
    .if \size > 0
    add sp, sp, #(((\size) + 15) & ~15)
    .endif
    ldp x29, x30, [sp], #16
.endm

#endif
