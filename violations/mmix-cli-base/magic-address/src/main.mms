        LOC     Data_Segment
ValueReg IS     $1
BaseReg IS      $2
        GREG    @
Message BYTE    "Hello, MMIX!",10,0
        LOC     #100
Main    LDO     ValueReg,BaseReg,#20
        LDA     $255,Message
        TRAP    0,Fputs,StdOut
        SETL    $255,0
        TRAP    0,Halt,0
