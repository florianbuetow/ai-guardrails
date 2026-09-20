// A realistic typo: mov takes two operands, not three.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__text

FUNC _bad_move
    mov x0, x1, x2
    ret
ENDFUNC _bad_move
