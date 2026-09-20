// Calls an undocumented dynamic-loader internal.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__text

FUNC _image_header
    FRAME_PUSH 0
    mov x0, #0
    bl __dyld_get_image_header
    FRAME_POP 0
    ret
ENDFUNC _image_header
