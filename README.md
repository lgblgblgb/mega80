# MEGA/80 - i8080 emulator and CP/M BIOS for MEGA65

I'm trying to renew my old project from 2017 to be able to run CP/M on MEGA65
with i8080 (for now, later: Z80) emulated in software equipped with a custom
CBIOS for the task. The 65816 CPU also seems to be a possible target to port
future Z80 emulation (I wouldn't do for the current i8080 since I will rewrite
the emulator anyway).

## Running CP/M

For now, i8080 CPU (which is the original CPU for CP/M, not the Z80) is emulated.
A custom CP/M v2.2 is provided dispatching the work to the native 65xx implementation
via HALT opcodes. For now, original DR's CPM (BDOS and CCP) v2.2 is used.

## Download

Have a look in directory `dist/bin` for a D81 disk image file (`mega65.d81`) for MEGA65.

Here is a link for you: https://raw.githubusercontent.com/lgblgblgb/mega80/refs/heads/master/dist/bin/mega65.d81

## Limitations / problems / plans

* Current code base is chaotic since major parts of it was written by me in 2017 and I only
  try to revive some unfinished old work of mine here
* So far only i8080 emulation, not Z80: newer CP/M programs written for Z80 won't work
* Even i8080 is not emulated perfectly, no half-carry flag and no DAA and for sure can be many bugs
* Original DR BDOS and CCP. There are open souce GNU/GPL replacements but requires Z80
* In nutshell, I would guess I'll go for Z80 emulation later and don't plan to fix i8080 emulation bugs too much
* No real disk access, CP/M disk image is copied to MEGA65 Attic RAM on startup and all changes later will be lost
* Only "dumb" terminal emulation, `CR`, `LF` and `BS` is interpreted. For more advanced CP/M programs, some terminal emulation should be done
* Need some tool which at least makes possible to easily import files into CP/M from MEGA65 SD card or such (at runtime)
* Porting to other systems: 65816 CPU seems to be a viable option for porting, and machines using that CPU and having enough memory:
    * Commodore 64 with SuperCPU (or even Commodore 128 with SuperCPU, though C128 already has a hardware Z80 built-in ...)
    * Commander X16 **is a no-no** since unfortunately they don't decode the bank at all (limited to 64K access), too bad :(
    * Apple IIgs? Unfortunately I don't know too much about Apple computers, but could be a fun ...
* Porting to non-65xx CPU based platforms: certainly it's not impossible but then you need to rewrite everything,
  as it's an assembly project and written in 65xx assembly (even to port to 65816 would require major modifications)
* Integrated on-the-fly memory monitor and things like that
* No, I don't plan CP/M v3 (as far as I can see now). The problem: it requires extensive bank switching and other difficulties,
  since I'm emulating i8080 (later hopefully a Z80) emulating bank switching would be impossible or very slow
* Native BDOS? Maybe adopoting Hjalfi's CPM65 with added Z80/i8080 CPU emulation to allow execute both ordinary
  CP/M (CP/M-80) and CP/M-65 applications.
    * Also a native BDOS-replacement can be written which does not use CP/M filesystem internally but normal FAT32,
      thus MEGA65's SD-card would be seen from CP/M as-is without major issue to import/export data/programs between
      MEGA65 and CP/M environment all the time.

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

### Standard UNIX stuff (like sed, make ...)

Using Linux or other kind of UNIX-class OS (including Mac) should be enough.

### Python 3

### c1541

### cpmtools

