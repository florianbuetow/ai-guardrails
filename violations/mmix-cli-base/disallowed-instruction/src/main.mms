        LOC     Data_Segment
StatusReg IS    $1
        GREG    @
Message BYTE    "Hello, MMIX!",10,0
        LOC     #100
Main    GET     StatusReg,rA
        LDA     $255,Message
        TRAP    0,Fputs,StdOut
        SETL    $255,0
        TRAP    0,Halt,0
