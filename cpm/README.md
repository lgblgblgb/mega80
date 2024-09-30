# BIOS.ASM

This a non-sense BIOS written by me, which mostly contains of HALT opcodes
only. The reason of this: my CPU emulator catches the HALT opcodes and uses
the PC value to tell the position of the HALT code in question and does the
needed operation in native mode.

# CPM22.ASM

cpm22.asm contains the CCP and BDOS assembly source code of a CP/M v2.2 system
in Z80 assembly syntax (though it's a i8080 material which was originally
written in i8080 assembly syntax format).

The file has been downloaded from https://github.com/Z80-Retro/cpm-2.2

which states:

## Original README of the Z80-Retro project

CP/M 2.2 Source, Manuals and Utilities

These files were retrieved from [The Unofficial CP/M Web site](http://www.cpm.z80.de/index.html)
and cleaned up in Feb 2023.

See the git commit history for changes.

## License

For licensing questions on original source code please have a look
on file DRI-LicenseAgreement.txt which was also presented there.

