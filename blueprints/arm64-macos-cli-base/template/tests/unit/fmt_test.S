// Unit tests for _fmt_i64.
//
// Exits 0 when every case passes, 1 on the first failure, naming the case
// on stderr.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__cstring
Lcase_zero:
    .asciz "fmt_test: zero formats as \"0\"\n"
.set LCASE_ZERO_LEN, . - Lcase_zero - 1
Lcase_positive:
    .asciz "fmt_test: positive value formats correctly\n"
.set LCASE_POSITIVE_LEN, . - Lcase_positive - 1
Lcase_negative:
    .asciz "fmt_test: negative value keeps its sign\n"
.set LCASE_NEGATIVE_LEN, . - Lcase_negative - 1
Lcase_wide:
    .asciz "fmt_test: multi-digit value formats correctly\n"
.set LCASE_WIDE_LEN, . - Lcase_wide - 1

.zerofill __DATA,__bss,_fmt_scratch,64,4

.section __TEXT,__text

FUNC _main
    FRAME_PUSH 16

    // 0 -> "0"
    mov x0, #0
    adrp x1, _fmt_scratch@PAGE
    add x1, x1, _fmt_scratch@PAGEOFF
    bl _fmt_i64
    cmp x0, #1
    b.ne Lfail_zero
    adrp x1, _fmt_scratch@PAGE
    add x1, x1, _fmt_scratch@PAGEOFF
    ldrb w2, [x1]
    cmp w2, #48
    b.ne Lfail_zero

    // 7 -> "7"
    mov x0, #7
    adrp x1, _fmt_scratch@PAGE
    add x1, x1, _fmt_scratch@PAGEOFF
    bl _fmt_i64
    cmp x0, #1
    b.ne Lfail_positive
    adrp x1, _fmt_scratch@PAGE
    add x1, x1, _fmt_scratch@PAGEOFF
    ldrb w2, [x1]
    cmp w2, #55
    b.ne Lfail_positive

    // -42 -> "-42"
    mov x0, #-42
    adrp x1, _fmt_scratch@PAGE
    add x1, x1, _fmt_scratch@PAGEOFF
    bl _fmt_i64
    cmp x0, #3
    b.ne Lfail_negative
    adrp x1, _fmt_scratch@PAGE
    add x1, x1, _fmt_scratch@PAGEOFF
    ldrb w2, [x1]
    cmp w2, #45
    b.ne Lfail_negative
    ldrb w2, [x1, #1]
    cmp w2, #52
    b.ne Lfail_negative
    ldrb w2, [x1, #2]
    cmp w2, #50
    b.ne Lfail_negative

    // 1024 -> "1024"
    mov x0, #1024
    adrp x1, _fmt_scratch@PAGE
    add x1, x1, _fmt_scratch@PAGEOFF
    bl _fmt_i64
    cmp x0, #4
    b.ne Lfail_wide
    adrp x1, _fmt_scratch@PAGE
    add x1, x1, _fmt_scratch@PAGEOFF
    ldrb w2, [x1]
    cmp w2, #49
    b.ne Lfail_wide
    ldrb w2, [x1, #3]
    cmp w2, #52
    b.ne Lfail_wide

    mov w0, #EXIT_OK
    FRAME_POP 16
    ret

Lfail_zero:
    adrp x1, Lcase_zero@PAGE
    add x1, x1, Lcase_zero@PAGEOFF
    mov x2, #LCASE_ZERO_LEN
    b Lfail_common

Lfail_positive:
    adrp x1, Lcase_positive@PAGE
    add x1, x1, Lcase_positive@PAGEOFF
    mov x2, #LCASE_POSITIVE_LEN
    b Lfail_common

Lfail_negative:
    adrp x1, Lcase_negative@PAGE
    add x1, x1, Lcase_negative@PAGEOFF
    mov x2, #LCASE_NEGATIVE_LEN
    b Lfail_common

Lfail_wide:
    adrp x1, Lcase_wide@PAGE
    add x1, x1, Lcase_wide@PAGEOFF
    mov x2, #LCASE_WIDE_LEN
    b Lfail_common

Lfail_common:
    mov x0, #STDERR_FD
    bl _io_write_all
    mov w0, #EXIT_FAIL
    FRAME_POP 16
    ret
ENDFUNC _main
