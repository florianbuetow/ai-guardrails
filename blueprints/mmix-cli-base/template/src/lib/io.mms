WriteStdout OR         $255,io_pointer,0
        TRAP    0,Fputs,StdOut
        POP     0,0

WriteStderr OR         $255,io_pointer,0
        TRAP    0,Fputs,StdErr
        POP     0,0

HaltWithCode OR        $255,exit_code,0
        TRAP    0,Halt,0
