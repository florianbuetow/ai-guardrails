// Bypasses libSystem with a raw syscall. Apple provides binary
// compatibility at the library level, not the syscall level.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__text

FUNC _raw_write
    mov x16, #4
    svc #0x80
    ret
ENDFUNC _raw_write
