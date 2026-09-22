        LOC     Data_Segment
data_base      GREG    @
arg_block      GREG    #6000000000000000
arg_count      GREG    0
arg_vector     GREG    0
input_pointer  GREG    0
parse_value    GREG    0
parse_status   GREG    0
format_pointer GREG    0
io_pointer     GREG    0
exit_code      GREG    0
compare_result GREG    0
scratch_char   GREG    0
scratch_next   GREG    0

output_buffer  BYTE    "0",10,0
invalid_error  BYTE    "error: expected a digit from 0 to 8",10,0
usage_error    BYTE    "usage: app <digit>",10,0

call_frame     IS      $0

        LOC     #100
Main    LDO     arg_count,arg_block,0
        CMP     compare_result,arg_count,2
        BNZ     compare_result,UsageError
        LDO     arg_vector,arg_block,8
        LDO     input_pointer,arg_vector,8
        PUSHJ   call_frame,ParseDigit
        BNZ     parse_status,InvalidInput
        PUSHJ   call_frame,FormatSuccess
        OR      io_pointer,format_pointer,0
        PUSHJ   call_frame,WriteStdout
        SETL    exit_code,0
        JMP     ExitProgram

InvalidInput LDA       io_pointer,invalid_error
        PUSHJ   call_frame,WriteStderr
        SETL    exit_code,1
        JMP     ExitProgram

UsageError LDA         io_pointer,usage_error
        PUSHJ   call_frame,WriteStderr
        SETL    exit_code,2
        JMP     ExitProgram

ExitProgram JMP        HaltWithCode
