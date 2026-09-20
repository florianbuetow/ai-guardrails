// Decimal formatting. Pure leaf module: no calls, no system interaction.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__text

// _fmt_i64(x0 = value, x1 = out) -> x0 = bytes written
//
// Writes the decimal representation of a signed 64-bit value to out.
// The caller must provide at least 20 bytes.
FUNC _fmt_i64
    FRAME_PUSH 32
    MOV x2, x1                  // output cursor
    mov x3, x0                  // working value
    mov x9, #0                  // negative flag
    cmp x3, #0
    b.ge Lfmt_magnitude
    mov x9, #1
    neg x3, x3
Lfmt_magnitude:
    mov x4, sp                  // reversed digit scratch
    mov x5, #0                  // digit count
    mov x6, #10
Lfmt_digits:
    udiv x7, x3, x6
    msub x8, x7, x6, x3
    add w8, w8, #48             // '0'
    strb w8, [x4, x5]
    add x5, x5, #1
    mov x3, x7
    cbnz x3, Lfmt_digits
    cbz x9, Lfmt_reverse
    mov w8, #45                 // '-'
    strb w8, [x2], #1
Lfmt_reverse:
    sub x5, x5, #1
    ldrb w8, [x4, x5]
    strb w8, [x2], #1
    cbnz x5, Lfmt_reverse
    sub x0, x2, x1
    FRAME_POP 32
    ret
ENDFUNC _fmt_i64
