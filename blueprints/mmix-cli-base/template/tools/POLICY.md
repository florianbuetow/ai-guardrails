# MMIX source policy

`validate` is a dependency-free, fail-fast policy checker for standalone MMIXAL
programs. Run it as `validate <source.mms>...`. Every input is checked as a
separate executable and must pass all of these rules. Run `validate --self-test`
to exercise its adversarial lexical and operand-boundary cases.

## Source form

- Source is printable ASCII with Unix newlines, a final newline, no tabs or
  trailing whitespace, and at most 100 columns per line.
- Labels begin in column 1 and operations begin in column 9. Labels are
  PascalCase ASCII letters and digits, fit in seven columns, and begin with an
  uppercase letter. Operands use commas without surrounding spaces.
- `%` starts a comment outside a string and must be preceded by a space when it
  follows code. Double-quoted strings must close on the same line.
- Each file has exactly one `LOC Data_Segment`, one `GREG @`, one later
  `LOC #100`, and exactly one instruction labeled `Main`. A `Main` directive
  does not satisfy the entry-point rule. Data directives are confined to the
  data segment and instructions to the code segment.
- Files are standalone. Include directives, external modules, and linker-style
  symbol imports are outside the accepted grammar.

## Operations

The validator accepts this instruction subset:

```text
ADD ADDU AND BDIF BN BNN BNP BNZ BP BZ CMP CMPU
CSN CSNN CSNP CSNZ CSP CSZ DIV DIVU GO JMP
LDB LDBU LDO LDOU LDT LDTU LDW LDWU MUL MULU MUX
NAND NEG NEGU NOR NXOR ODIF OR ORH ORL ORMH ORML
PBN PBNN PBNP PBNZ PBP PBZ POP PUSHJ
SET SETH SETL SETMH SETML SL SLU SR SRU
STB STBU STCO STO STOU STT STTU STW STWU SUB SUBU
TDIF TRAP WDIF XOR ZSN ZSNN ZSNP ZSNZ ZSP ZSZ
```

The accepted directives are `BYTE`, `GREG`, `IS`, `LOC`, `OCTA`, `TETRA`, and `WYDE`.
All other operations are rejected, including privileged state manipulation,
self-modifying execution controls, synchronization instructions, and pseudo-op
include mechanisms.

## Registers, addresses, and traps

- Local registers `$0` through `$254` must be declared as aliases with
  `PascalCaseReg IS $n` and referenced by that name in instructions. `IS` may
  only alias one local register. `$255` cannot be aliased.
- The first register position of each ordinary instruction must contain a
  `PascalCaseReg` alias or explicit `$255`. This rejects MMIXAL's alternate
  decimal spelling of a destination register (for example `SETL 255,1`).
- `$255` is reserved for `LDA $255,PascalCaseSymbol` when passing a string to
  `Fputs`, and `SETL $255,0` immediately before the conventional halt path.
  Other uses are rejected.
- `GREG` is accepted only in the unlabeled form `GREG @`, which MMIXAL needs to
  materialize addresses after the data segment. Named or value-bearing `GREG`
  declarations are rejected so register allocation cannot change silently as
  declarations are reordered.
- `LOC` accepts only `Data_Segment` and `#100`. Hexadecimal instruction
  operands are rejected as magic addresses. Named symbols and named register
  aliases make address and register intent visible.
- `TRAP` accepts exactly `0,Fputs,StdOut` and `0,Halt,0`. Programs cannot open
  files, invoke host-specific services, or select traps by numeric magic value.

This checker intentionally validates a narrow project dialect rather than all
valid MMIXAL. `mmixal` remains the authority for assembly syntax and semantics;
the local policy checker runs before it.
