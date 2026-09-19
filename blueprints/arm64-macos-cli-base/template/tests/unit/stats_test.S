// Unit tests for the stats module.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__cstring
Lcase_empty:
    .asciz "stats_test: a fresh state counts zero\n"
.set LCASE_EMPTY_LEN, . - Lcase_empty - 1
Lcase_count:
    .asciz "stats_test: update advances the count\n"
.set LCASE_COUNT_LEN, . - Lcase_count - 1
Lcase_sum:
    .asciz "stats_test: update accumulates the sum\n"
.set LCASE_SUM_LEN, . - Lcase_sum - 1
Lcase_max:
    .asciz "stats_test: max keeps the largest value\n"
.set LCASE_MAX_LEN, . - Lcase_max - 1
Lcase_negative_max:
    .asciz "stats_test: max works with only negative values\n"
.set LCASE_NEGATIVE_MAX_LEN, . - Lcase_negative_max - 1
Lcase_overflow:
    .asciz "stats_test: sum overflow is reported\n"
.set LCASE_OVERFLOW_LEN, . - Lcase_overflow - 1

.section __TEXT,__text

// Frame: [sp,#0] stats state (24 bytes)
FUNC _main
    FRAME_PUSH 32

    mov x0, sp
    bl _stats_init
    mov x0, sp
    bl _stats_count
    cbnz x0, Lfail_empty

    // 5, -7, 12 -> count 3, sum 10, max 12
    mov x0, sp
    mov x1, #5
    bl _stats_update
    cbnz w0, Lfail_count
    mov x0, sp
    mov x1, #-7
    bl _stats_update
    cbnz w0, Lfail_count
    mov x0, sp
    mov x1, #12
    bl _stats_update
    cbnz w0, Lfail_count

    mov x0, sp
    bl _stats_count
    cmp x0, #3
    b.ne Lfail_count

    mov x0, sp
    bl _stats_sum
    cmp x0, #10
    b.ne Lfail_sum

    mov x0, sp
    bl _stats_max
    cmp x0, #12
    b.ne Lfail_max

    // Only negative values: max must not stay at the INT64_MIN sentinel.
    mov x0, sp
    bl _stats_init
    mov x0, sp
    mov x1, #-3
    bl _stats_update
    mov x0, sp
    mov x1, #-9
    bl _stats_update
    mov x0, sp
    bl _stats_max
    cmp x0, #-3
    b.ne Lfail_negative_max

    // INT64_MAX + 1 must report overflow rather than wrapping.
    mov x0, sp
    bl _stats_init
    mov x1, #1
    lsl x1, x1, #63
    sub x1, x1, #1          // INT64_MAX
    mov x0, sp
    bl _stats_update
    cbnz w0, Lfail_overflow
    mov x0, sp
    mov x1, #1
    bl _stats_update
    cbz w0, Lfail_overflow

    mov w0, #EXIT_OK
    FRAME_POP 32
    ret

Lfail_empty:
    adrp x1, Lcase_empty@PAGE
    add x1, x1, Lcase_empty@PAGEOFF
    mov x2, #LCASE_EMPTY_LEN
    b Lfail_common

Lfail_count:
    adrp x1, Lcase_count@PAGE
    add x1, x1, Lcase_count@PAGEOFF
    mov x2, #LCASE_COUNT_LEN
    b Lfail_common

Lfail_sum:
    adrp x1, Lcase_sum@PAGE
    add x1, x1, Lcase_sum@PAGEOFF
    mov x2, #LCASE_SUM_LEN
    b Lfail_common

Lfail_max:
    adrp x1, Lcase_max@PAGE
    add x1, x1, Lcase_max@PAGEOFF
    mov x2, #LCASE_MAX_LEN
    b Lfail_common

Lfail_negative_max:
    adrp x1, Lcase_negative_max@PAGE
    add x1, x1, Lcase_negative_max@PAGEOFF
    mov x2, #LCASE_NEGATIVE_MAX_LEN
    b Lfail_common

Lfail_overflow:
    adrp x1, Lcase_overflow@PAGE
    add x1, x1, Lcase_overflow@PAGEOFF
    mov x2, #LCASE_OVERFLOW_LEN
    b Lfail_common

Lfail_common:
    mov x0, #STDERR_FD
    bl _io_write_all
    mov w0, #EXIT_FAIL
    FRAME_POP 32
    ret
ENDFUNC _main
