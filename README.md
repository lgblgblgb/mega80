# MEGA80: i8080 emulator and CPM BIOS for MEGA65

I'm trying to renew my old project from 2017 to be able to run CP/M on MEGA65
with i8080 (for now, later: Z80) emulated in software equipped with a custom
CBIOS for the task. The 65816 CPU also seems to be a possible target to port
future Z80 emulation.

## Running CP/M

For now, i8080 CPU (which is the original CPU for CP/M, not the Z80) is emulated.
A custom CP/M v2.2 is provided dispatching the work to the native 65xx implementation
via HALT opcodes. For now, original DR's CPM (BDOS and CCP) v2.2 is used.

## Building

Tools needed to build:

### CC65

Various tools (ca65, ld65, cl65) from the CC65 suite to assemble 65xx assembly sources:

Only tested with V2.18 (as of I am writing this), so any older version can cause
problems. Currently the C compiler part (cc65) is not used though.

### SjASMPlus

SjASMPlus Z80 Cross-Assembler to assemble i8080 / Z80 assembly sources: https://github.com/z00m128/sjasmplus

Only tested with version v1.20.3 (as of I am writing this), so any older version
can cause problems, like certain ASSERT features was introduced in v1.18.1 but there
can be other problems as well.

### Standard UNIX stuff, like sed, make ...

### Python 3

### c1541
