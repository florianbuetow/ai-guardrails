// Uses x18, which Apple reserves on arm64.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__text

FUNC _stash_value
    mov x18, x0
    mov x0, x18
    ret
ENDFUNC _stash_value
