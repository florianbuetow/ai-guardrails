FormatSuccess ADDU     scratch_char,parse_value,1
        ADDU    scratch_char,scratch_char,'0'
        LDA     format_pointer,output_buffer
        STBU    scratch_char,format_pointer,0
        POP     0,0
