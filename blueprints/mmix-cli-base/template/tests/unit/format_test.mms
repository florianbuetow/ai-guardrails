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

call_frame     IS      $0

        LOC     #100
Main    SETL    parse_value,8
        PUSHJ   call_frame,FormatSuccess
        LDBU    scratch_char,format_pointer,0
        CMP     compare_result,scratch_char,'9'
        BNZ     compare_result,TestFailure
        LDBU    scratch_char,format_pointer,1
        CMP     compare_result,scratch_char,10
        BNZ     compare_result,TestFailure
        LDBU    scratch_char,format_pointer,2
        BNZ     scratch_char,TestFailure
        SETL    exit_code,0
        JMP     HaltWithCode

TestFailure SETL       exit_code,1
        JMP     HaltWithCode
