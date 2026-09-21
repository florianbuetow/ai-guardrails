        LOC     Data_Segment
        GREG    @
Message BYTE    "Hello, MMIX!",10,0
        LOC     #100
Main    LDA     $255,Message
        SETL    $255,0
        TRAP    0,Fputs,StdOut
        TRAP    0,Halt,0
