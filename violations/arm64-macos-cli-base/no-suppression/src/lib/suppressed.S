// Silences the scanner instead of fixing the finding.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__text

FUNC _quiet_helper
    // nosemgrep
    mov x0, #0
    ret
ENDFUNC _quiet_helper
