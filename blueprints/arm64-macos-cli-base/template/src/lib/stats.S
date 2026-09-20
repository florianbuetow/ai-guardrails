// Running statistics. Pure leaf module: no calls, no system interaction.
//
// State layout, 24 bytes, 8-byte aligned:
//   [0]  count
//   [8]  sum
//   [16] max

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__text

// _stats_init(x0 = state)
//
// max starts at INT64_MIN. A caller that reports max without first
// checking count would surface that sentinel, so _main treats empty
// input as a runtime failure rather than inventing a value.
FUNC _stats_init
    str xzr, [x0]
    str xzr, [x0, #8]
    mov x1, #1
    lsl x1, x1, #63
    str x1, [x0, #16]
    ret
ENDFUNC _stats_init

// _stats_update(x0 = state, x1 = value) -> w0 = 0 ok | 1 sum overflow
FUNC _stats_update
    ldr x2, [x0]
    add x2, x2, #1
    ldr x3, [x0, #8]
    adds x3, x3, x1
    b.vs Lstats_overflow
    str x2, [x0]
    str x3, [x0, #8]
    ldr x4, [x0, #16]
    cmp x1, x4
    csel x4, x1, x4, gt
    str x4, [x0, #16]
    mov w0, #0
    ret
Lstats_overflow:
    mov w0, #1
    ret
ENDFUNC _stats_update

// _stats_count(x0 = state) -> x0 = count
FUNC _stats_count
    ldr x0, [x0]
    ret
ENDFUNC _stats_count

// _stats_sum(x0 = state) -> x0 = sum
FUNC _stats_sum
    ldr x0, [x0, #8]
    ret
ENDFUNC _stats_sum

// _stats_max(x0 = state) -> x0 = max
FUNC _stats_max
    ldr x0, [x0, #16]
    ret
ENDFUNC _stats_max
