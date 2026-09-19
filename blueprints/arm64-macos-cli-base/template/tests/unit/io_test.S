// Unit tests for the io module.
//
// These use /dev/null so the suite needs no temporary files and no
// hardcoded paths under a user or temp directory.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__cstring
Ldev_null:
    .asciz "/dev/null"
Lnot_a_directory:
    .asciz "/dev/null/nope"

Lcase_open:
    .asciz "io_test: opening /dev/null succeeds\n"
.set LCASE_OPEN_LEN, . - Lcase_open - 1
Lcase_read:
    .asciz "io_test: reading /dev/null yields zero bytes\n"
.set LCASE_READ_LEN, . - Lcase_read - 1
Lcase_write:
    .asciz "io_test: writes report failure on a read-only descriptor\n"
.set LCASE_WRITE_LEN, . - Lcase_write - 1
Lcase_missing:
    .asciz "io_test: opening an invalid path reports failure\n"
.set LCASE_MISSING_LEN, . - Lcase_missing - 1

.zerofill __DATA,__bss,_io_scratch,256,4

.section __TEXT,__text

// Frame: [sp,#0] fd
FUNC _main
    FRAME_PUSH 16

    adrp x0, Ldev_null@PAGE
    add x0, x0, Ldev_null@PAGEOFF
    bl _io_open
    cmp x0, #0
    b.lt Lfail_open
    str x0, [sp]

    ldr x0, [sp]
    adrp x1, _io_scratch@PAGE
    add x1, x1, _io_scratch@PAGEOFF
    mov x2, #256
    bl _io_read_all
    cmp x0, #0
    b.ne Lfail_read

    // _io_open uses O_RDONLY, so writing to that descriptor must be
    // reported as a failure rather than silently ignored.
    ldr x0, [sp]
    adrp x1, Lcase_write@PAGE
    add x1, x1, Lcase_write@PAGEOFF
    mov x2, #LCASE_WRITE_LEN
    bl _io_write_all
    cbz w0, Lfail_write

    // A zero-length write succeeds without emitting anything.
    mov x0, #STDERR_FD
    adrp x1, Lcase_write@PAGE
    add x1, x1, Lcase_write@PAGEOFF
    mov x2, #0
    bl _io_write_all
    cbnz w0, Lfail_write

    ldr x0, [sp]
    bl _io_close

    adrp x0, Lnot_a_directory@PAGE
    add x0, x0, Lnot_a_directory@PAGEOFF
    bl _io_open
    cmp x0, #0
    b.ge Lfail_missing

    mov w0, #EXIT_OK
    FRAME_POP 16
    ret

Lfail_open:
    adrp x1, Lcase_open@PAGE
    add x1, x1, Lcase_open@PAGEOFF
    mov x2, #LCASE_OPEN_LEN
    b Lfail_common

Lfail_read:
    adrp x1, Lcase_read@PAGE
    add x1, x1, Lcase_read@PAGEOFF
    mov x2, #LCASE_READ_LEN
    b Lfail_common

Lfail_write:
    adrp x1, Lcase_write@PAGE
    add x1, x1, Lcase_write@PAGEOFF
    mov x2, #LCASE_WRITE_LEN
    b Lfail_common

Lfail_missing:
    adrp x1, Lcase_missing@PAGE
    add x1, x1, Lcase_missing@PAGEOFF
    mov x2, #LCASE_MISSING_LEN
    b Lfail_common

Lfail_common:
    mov x0, #STDERR_FD
    bl _io_write_all
    mov w0, #EXIT_FAIL
    FRAME_POP 16
    ret
ENDFUNC _main
