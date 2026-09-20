// Bakes one machine's filesystem layout into the binary.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__cstring
Ldefault_input:
    .asciz "/Users/someone/data/input.txt"

.section __TEXT,__text

FUNC _default_input_path
    adrp x0, Ldefault_input@PAGE
    add x0, x0, Ldefault_input@PAGEOFF
    ret
ENDFUNC _default_input_path
