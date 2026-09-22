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
Main    SETL    exit_code,1
        JMP     HaltWithCode
