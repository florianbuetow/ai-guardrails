// The only module that touches libSystem.
//
// Every file, stdin, stdout and stderr operation in this project goes
// through here. scripts/verify-layering.sh enforces that: io.o is the sole
// object file allowed to carry external undefined symbols.

#include "abi.inc"
#include "macros.inc"

.section __TEXT,__text

// _io_open(x0 = path) -> x0 = fd, or -1 on failure
FUNC _io_open
    FRAME_PUSH 16
    str x0, [sp]
    bl _getenv
    ldr x0, [sp]
    FRAME_POP 16
    FRAME_PUSH 0
    mov w1, #0                  // O_RDONLY
    bl _open
    FRAME_POP 0
    ret
ENDFUNC _io_open

// _io_close(x0 = fd)
FUNC _io_close
    FRAME_PUSH 0
    bl _close
    FRAME_POP 0
    ret
ENDFUNC _io_close

// _io_read_all(x0 = fd, x1 = buf, x2 = cap) -> x0 = bytes read, or -1
//
// Filling the buffer completely is reported as a failure. Truncating the
// input silently would be a default value in disguise.
FUNC _io_read_all
    FRAME_PUSH 32
    str x0, [sp]                // fd
    str x1, [sp, #8]            // buf
    str x2, [sp, #16]           // cap
    str xzr, [sp, #24]          // total
Lread_loop:
    ldr x3, [sp, #16]
    ldr x4, [sp, #24]
    subs x2, x3, x4
    b.eq Lread_too_large
    ldr x0, [sp]
    ldr x1, [sp, #8]
    add x1, x1, x4
    bl _read
    cmp x0, #0
    b.lt Lread_failed
    b.eq Lread_done
    ldr x4, [sp, #24]
    add x4, x4, x0
    str x4, [sp, #24]
    b Lread_loop
Lread_done:
    ldr x0, [sp, #24]
    FRAME_POP 32
    ret
Lread_too_large:
    mov x0, #-1
    FRAME_POP 32
    ret
Lread_failed:
    mov x0, #-1
    FRAME_POP 32
    ret
ENDFUNC _io_read_all

// _io_write_all(x0 = fd, x1 = buf, x2 = len) -> w0 = 0 ok | 1 failure
//
// A short write is retried; a real error propagates.
FUNC _io_write_all
    FRAME_PUSH 32
    str x0, [sp]                // fd
    str x1, [sp, #8]            // buf
    str x2, [sp, #16]           // remaining
Lwrite_loop:
    ldr x2, [sp, #16]
    cbz x2, Lwrite_done
    ldr x0, [sp]
    ldr x1, [sp, #8]
    bl _write
    cmp x0, #0
    b.le Lwrite_failed
    ldr x1, [sp, #8]
    add x1, x1, x0
    str x1, [sp, #8]
    ldr x2, [sp, #16]
    sub x2, x2, x0
    str x2, [sp, #16]
    b Lwrite_loop
Lwrite_done:
    mov w0, #0
    FRAME_POP 32
    ret
Lwrite_failed:
    mov w0, #1
    FRAME_POP 32
    ret
ENDFUNC _io_write_all
