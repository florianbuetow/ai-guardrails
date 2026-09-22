ParseDigit LDBU        scratch_char,input_pointer,0
        LDBU    scratch_next,input_pointer,1
        BNZ     scratch_next,ParseFailure
        CMP     compare_result,scratch_char,'0'
        BN      compare_result,ParseFailure
        CMP     compare_result,scratch_char,'8'
        BP      compare_result,ParseFailure
        SUBU    parse_value,scratch_char,'0'
        SETL    parse_status,0
        POP     0,0

ParseFailure SETL      parse_status,1
        POP     0,0
        % This intentionally exceeds the MMIXAL input buffer and must be diagnosed as an assembler warning.
