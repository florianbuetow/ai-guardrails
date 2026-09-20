// Decimal parsing. Pure leaf module: no calls, no system interaction.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__text

// _parse_i64(x0 = ptr, x1 = len) -> x0 = value, w1 = status
//
// status is PARSE_OK, PARSE_MALFORMED or PARSE_OVERFLOW. An empty slice,
// a lone sign, and any non-digit byte are all malformed: the parser never
// guesses a value for input it does not fully understand.
FUNC _parse_i64
    cbz x1, Lparse_malformed
    mov x2, x0                  // cursor
    mov x3, x1                  // remaining
    mov x4, #0                  // magnitude accumulator
    mov w5, #0                  // negative flag
    mov x10, #10
    ldrb w6, [x2]
    cmp w6, #45                 // '-'
    b.ne Lparse_loop
    mov w5, #1
    add x2, x2, #1
    sub x3, x3, #1
    cbz x3, Lparse_malformed
Lparse_loop:
    ldrb w6, [x2], #1
    sub w6, w6, #48             // '0'
    cmp w6, #9
    b.hi Lparse_done
    umulh x8, x4, x10
    cbnz x8, Lparse_overflow
    mul x4, x4, x10
    adds x4, x4, x6
    b.mi Lparse_overflow
    subs x3, x3, #1
    b.ne Lparse_loop
    cbz w5, Lparse_done
    neg x4, x4
Lparse_done:
    mov x0, x4
    mov w1, #PARSE_OK
    ret
Lparse_malformed:
    mov x0, #0
    mov w1, #PARSE_MALFORMED
    ret
Lparse_overflow:
    mov x0, #0
    mov w1, #PARSE_OVERFLOW
    ret
ENDFUNC _parse_i64
