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
valid_input    BYTE    "4",0
long_input     BYTE    "42",0
low_input      BYTE    "/",0
high_input     BYTE    "9",0

call_frame     IS      $0

        LOC     #100
Main    LDA     input_pointer,valid_input
        PUSHJ   call_frame,ParseDigit
        BNZ     parse_status,TestFailure
        CMP     compare_result,parse_value,4
        BNZ     compare_result,TestFailure
        LDA     input_pointer,long_input
        PUSHJ   call_frame,ParseDigit
        BZ      parse_status,TestFailure
        LDA     input_pointer,low_input
        PUSHJ   call_frame,ParseDigit
        BZ      parse_status,TestFailure
        LDA     input_pointer,high_input
        PUSHJ   call_frame,ParseDigit
        BZ      parse_status,TestFailure
        SETL    exit_code,0
        JMP     HaltWithCode

TestFailure SETL       exit_code,1
        JMP     HaltWithCode
