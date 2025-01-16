# Supported instructions

> Followed by `MIPS® Architecture For Programmers Volume II-A: The MIPS64® Instruction Set`, Document Number: MD00087, Revision 6.06, December 15, 2016
> 
> And `MIPS® Architecture For Programmers Volume III: MIPS64® / microMIPS64™ Privileged Resource Architecture`, Document Number: MD00091, Revision 6.03, December 22, 2015
>
> Note: `₆₄` means it added in MIPS64. Most of `U` suffix in instruction are suppressing arithmetic overflow exception.

## Arithmetic Operations

- Addition Family
  - `ADD` / `ADDU` - Register addition
  - `ADDI` / `ADDIU` - Immediate Addition
  - `DADD`₆₄ / `DADDU`₆₄ - Register Addition
  - `DADDI`₆₄ / `DADDIU`₆₄ - Double Word Immediate Addition
- Subtraction Family
  - `SUB` / `SUBU` - Register Subtraction
  - `DSUB`₆₄ - Double Word Subtraction

## Logical Operations

- Bitwise Operations
  - `AND` - Bitwise AND
  - `OR` / `ORI` - Bitwise OR
  - `XOR` / `XORI` - Bitwise XOR
  - `NOR` - Bitwise NOR
- Shift Operations
  - `SLL` / `SRL` - Regular Shift
  - `DSLL`₆₄ / `DSRL`₆₄ - Double Word Shift
  - `DSLL32`₆₄ / `DSRL32`₆₄ - Double Word Shift Logical Plus 32 (shift 32-63 bits)

## Comparison Instructions

- `SLT` / `SLTU` - Set Less Than
- `SLTI` / `SLTIU` - Set Less Than Immediate

### Load Upper Instructions

- `LUI` - Load Upper Immediate (loads constant into upper half of word)

## Branch and Jump Instructions

- `J` - Jump
- `JR` - Jump Register
- `BEQ` - Branch if Equal
- `BNE` - Branch if Not Equal
- `BC` - Branch, Compact

## Memory Access Instructions

- Load Operations
  - `LB` / `LBU` - Load Byte
  - `LW` / `LWU` - Load Word
  - `LD`₆₄ - Load Double Word
- Store Operations
  - `SB` - Store Byte
  - `SW` - Store Word
  - `SD`₆₄ - Store Double Word

## Privileged Instructions

- `ERET` - Exception Return To Previous PC
- `MFC0` / `MTC0` - Coprocessor0 Register Read / Write
