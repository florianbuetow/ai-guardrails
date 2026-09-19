// Unit tests for _parse_i64.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__cstring
Ldigits:
    .asciz "123"
Lnegative:
    .asciz "-5"
Lsign_only:
    .asciz "-"
Ltrailing_alpha:
    .asciz "12a"
Ltoo_large:
    .asciz "99999999999999999999"

Lcase_digits:
    .asciz "parse_test: plain digits parse\n"
.set LCASE_DIGITS_LEN, . - Lcase_digits - 1
Lcase_negative:
    .asciz "parse_test: negative values parse\n"
.set LCASE_NEGATIVE_LEN, . - Lcase_negative - 1
Lcase_empty:
    .asciz "parse_test: empty slice is malformed\n"
.set LCASE_EMPTY_LEN, . - Lcase_empty - 1
Lcase_sign_only:
    .asciz "parse_test: a lone sign is malformed\n"
.set LCASE_SIGN_ONLY_LEN, . - Lcase_sign_only - 1
Lcase_alpha:
    .asciz "parse_test: trailing non-digit is malformed\n"
.set LCASE_ALPHA_LEN, . - Lcase_alpha - 1
Lcase_overflow:
    .asciz "parse_test: out-of-range value reports overflow\n"
.set LCASE_OVERFLOW_LEN, . - Lcase_overflow - 1

.section __TEXT,__text

FUNC _main
    FRAME_PUSH 16

    // "123" -> 123, PARSE_OK
    adrp x0, Ldigits@PAGE
    add x0, x0, Ldigits@PAGEOFF
    mov x1, #3
    bl _parse_i64
    cmp w1, #PARSE_OK
    b.ne Lfail_digits
    cmp x0, #123
    b.ne Lfail_digits

    // "-5" -> -5, PARSE_OK
    adrp x0, Lnegative@PAGE
    add x0, x0, Lnegative@PAGEOFF
    mov x1, #2
    bl _parse_i64
    cmp w1, #PARSE_OK
    b.ne Lfail_negative
    cmp x0, #-5
    b.ne Lfail_negative

    // empty slice -> PARSE_MALFORMED
    adrp x0, Ldigits@PAGE
    add x0, x0, Ldigits@PAGEOFF
    mov x1, #0
    bl _parse_i64
    cmp w1, #PARSE_MALFORMED
    b.ne Lfail_empty

    // "-" -> PARSE_MALFORMED
    adrp x0, Lsign_only@PAGE
    add x0, x0, Lsign_only@PAGEOFF
    mov x1, #1
    bl _parse_i64
    cmp w1, #PARSE_MALFORMED
    b.ne Lfail_sign_only

    // "12a" -> PARSE_MALFORMED
    adrp x0, Ltrailing_alpha@PAGE
    add x0, x0, Ltrailing_alpha@PAGEOFF
    mov x1, #3
    bl _parse_i64
    cmp w1, #PARSE_MALFORMED
    b.ne Lfail_alpha

    // 20 nines -> PARSE_OVERFLOW
    adrp x0, Ltoo_large@PAGE
    add x0, x0, Ltoo_large@PAGEOFF
    mov x1, #20
    bl _parse_i64
    cmp w1, #PARSE_OVERFLOW
    b.ne Lfail_overflow

    mov w0, #EXIT_OK
    FRAME_POP 16
    ret

Lfail_digits:
    adrp x1, Lcase_digits@PAGE
    add x1, x1, Lcase_digits@PAGEOFF
    mov x2, #LCASE_DIGITS_LEN
    b Lfail_common

Lfail_negative:
    adrp x1, Lcase_negative@PAGE
    add x1, x1, Lcase_negative@PAGEOFF
    mov x2, #LCASE_NEGATIVE_LEN
    b Lfail_common

Lfail_empty:
    adrp x1, Lcase_empty@PAGE
    add x1, x1, Lcase_empty@PAGEOFF
    mov x2, #LCASE_EMPTY_LEN
    b Lfail_common

Lfail_sign_only:
    adrp x1, Lcase_sign_only@PAGE
    add x1, x1, Lcase_sign_only@PAGEOFF
    mov x2, #LCASE_SIGN_ONLY_LEN
    b Lfail_common

Lfail_alpha:
    adrp x1, Lcase_alpha@PAGE
    add x1, x1, Lcase_alpha@PAGEOFF
    mov x2, #LCASE_ALPHA_LEN
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
    FRAME_POP 16
    ret
ENDFUNC _main
