# TODO

Trying to renew my old project from 2017 to be able to run CP/M on MEGA65
with i8080 (for now, later: Z80) emulated in software.

Tools needed to build:

Various tools (ca65, ld65, cl65) from the CC65 suite to assemble 65xx assembly sources:

Only tested with V2.18 (as of I am writing this), so any older version can cause
problems. Currently the C compiler part (cc65) is not used though.

SjASMPlus Z80 Cross-Assembler to assemble i8080 / Z80 assembly sources: https://github.com/z00m128/sjasmplus

Only tested with version v1.20.3 (as of I am writing this), so any older version
can cause problems, like certain ASSERT features was introduced in v1.18.1 but there
can be other problems as well.
