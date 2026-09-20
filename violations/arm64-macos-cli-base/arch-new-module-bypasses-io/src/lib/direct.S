// Calls libSystem directly instead of going through io.S, which is the
// project's only permitted system boundary.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__text

FUNC _direct_write
    FRAME_PUSH 0
    bl _write
    FRAME_POP 0
    ret
ENDFUNC _direct_write
