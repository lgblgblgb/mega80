#!/usr/bin/env python

import sys

# http://unusedino.de/ec64/technical/formats/d81.html

#### --[ Do NOT edit these numbers! ]--
D81_SIZE = 819200                      ;
TRACK_SIZE = 40 * 256                  ;
#### ----------------------------------

with open("../emu.prg", "rb") as psize:
    psize = len(psize.read())

print("Size of MEGA/80 program is: {}".format(psize))

psize = (psize // 254) + (1 if psize % 254 != 0 else 0)

print("Blocks needed for MEGA/80: {}".format(psize))

psize = (psize // 40) + (1 if psize % 40 != 0 else 0)

print("Tracks needed for MEGA/80: {}".format(psize))


# Must be 1024 or 2048
CPM_BLOCKSIZE = 2048
#CPM_TRACKS = SLICE0_TRACKS + SLICE1_TRACKS
#CPM_SECTORS = TRACK_SIZE / 128



# Number of tracks to be reserved for CBM-DOS (less CP/M disk space!)
# This does NOT include the one track CBM-DOS directory track, that's always reserved even if RESERVE is set to 0 here
# One track is 10Kbytes (TRACK_SIZE)
# Set to "psize" to allow emulator to fit!
RESERVE = 0

SLICE0_TRACKS = 39 - RESERVE      # This slice is from track 1 to 39 (or lower when reserved track exist), track 40 is CBM directory track!!!!
SLICE1_TRACKS = 40                # This slice is from track 41 to 80, 40 tracks in total


CAPACITY = (SLICE0_TRACKS + SLICE1_TRACKS) * TRACK_SIZE
CPM_TRACKS = CAPACITY / (128 * 4)   # in CP/M we use 4 sectors per track ...
SLICE0_CPM_TRACKS = SLICE0_TRACKS * 40 / 2
CPM_CAPACITY = CAPACITY // CPM_BLOCKSIZE

if CAPACITY % CPM_BLOCKSIZE:
    raise RuntimeError("Bad capacity vs CP/M blocksize")


print("D81-size = {}, CP/M-size = {} ({}%), CP/M alloc units = {}, CP/M tracks (slice0) = {} ({})".format(D81_SIZE, CAPACITY, 100 * CAPACITY // D81_SIZE, CPM_CAPACITY, CPM_TRACKS, SLICE0_CPM_TRACKS))


def setname(bs, offs, size, filler, text):
    for a in range(size):
        bs[offs + a] = ord(text[a]) if a < len(text) else filler




disk = bytearray(D81_SIZE)

if False:
    for a in (
        (0x00061800, "28 03 44 00 4c 47 42 a0 a0 a0 a0 a0 a0 a0 a0 a0 a0 a0 a0 a0 a0 a0 49 44 a0 33 44 a0 a0"),
        (0x00061900, "28 02 44 bb 49 44 c0"),
        (0x00061910, "25 f4 ff ff ff ff"),
        (0x000619f0, "00 00 00 00 00 00 00 00 00 00 24 f0 ff ff ff ff 00 ff 44 bb 49 44 c0"),
        (0x00061ae0, "00 00 28 ff ff ff ff ff 28 ff ff ff ff ff 28 ff"),
        (0x00061af0, "ff ff ff ff 28 ff ff ff ff ff 28 ff ff ff ff ff"),
        (0x00061b00, "00 ff"),
    ):
        a, s = a[0], [int(x, 16) for x in a[1].strip().split()]
        disk[a : a + len(s)] = s

DISK_ID0 = ord("8")
DISK_ID1 = ord("0")
CBM_VER = 0x44


# track 40, sector 0: head sector, disk name ...
# track 40, sector 1: BAM - part 1
# track 40, sector 2: BAM - part 2
# track 40, sector 3: the first directory sector

o = 0x61800

disk[o + 0x00] = 40    # ptr to directory track and sector, must be 40/3
disk[o + 0x01] =  3    # -----""------
disk[o + 0x02] = CBM_VER
setname(disk, o + 0x04, 16, 0xA0, "MEGA/80 BOOT DSK")
disk[o + 0x14] = 0xA0
disk[o + 0x15] = 0xA0
disk[o + 0x16] = DISK_ID0
disk[o + 0x17] = DISK_ID1
disk[o + 0x18] = 0xA0
disk[o + 0x19] = ord("3")
disk[o + 0x1A] = ord("D")
disk[o + 0x1B] = 0xA0
disk[o + 0x1C] = 0xA0
# MEGA/80 extensions, CP/M disk geometry info:
setname(disk, o + 0xAD, 16, 0xA0, "MEGA80")
# disk[o + 0xC0] <--- this will be the start of the stuff
# ...-> Copy of slice0 dir entry
# ...-> Copy of slice1 dir entry



#      0  1  2  3  4  5  6
# 00: 28 02 44 BB 47 42 C0 00 00 00 00 00 00 00 00 00   (.D?GB+?????????
#     00 FF 44 BB 47 42 C0 00 00 00 00 00 00 00 00 00   (.D?GB+?????????

disk[o + 0x100] = 40
disk[o + 0x200] = 0x00
disk[o + 0x101] =  2
disk[o + 0x201] = 0xFF
disk[o + 0x102] = CBM_VER
disk[o + 0x202] = CBM_VER
disk[o + 0x103] = 0xFF - CBM_VER
disk[o + 0x203] = 0xFF - CBM_VER
disk[o + 0x104] = DISK_ID0
disk[o + 0x204] = DISK_ID0
disk[o + 0x105] = DISK_ID1
disk[o + 0x205] = DISK_ID1
disk[o + 0x106] = 0xC0
disk[o + 0x206] = 0xC0


disk[o + 0x300] = 0
disk[o + 0x301] = 0xFF


disk[o + 0x3C2] = 0x85 + 0x40   # file type: CBM + lock bit
disk[o + 0x3C3] = 1             # starts on track 1
disk[o + 0x3C4] = 0             # ... and sector 0
setname(disk, o + 0x3C5, 16, 0xA0, "CP/M DISK POOL 0")
disk[o + 0x3DE] = (SLICE0_TRACKS * 40) & 0xFF
disk[o + 0x3DF] = (SLICE0_TRACKS * 40) >> 8

disk[o + 0x3E2] = 0x85 + 0x40   # file type: CBM + lock bit
disk[o + 0x3E3] = 41            # starts on track 41
disk[o + 0x3E4] = 0             # ... and sector 0
setname(disk, o + 0x3E5, 16, 0xA0, "CP/M DISK POOL 1")
disk[o + 0x3FE] = (SLICE1_TRACKS * 40) & 0xFF
disk[o + 0x3FF] = (SLICE1_TRACKS * 40) >> 8

for a in range(64):
    disk[o + 0x0C0 + a] = disk[o + 0x3C0 + a] ^ 0xFF








with open("test.d81","wb") as f:
    f.write(disk)










"""
plan.d81:


00061800  28 03 44 00 4c 47 42 a0  a0 a0 a0 a0 a0 a0 a0 a0  |(.D.LGB.........|
00061810  a0 a0 a0 a0 a0 a0 49 44  a0 33 44 a0 a0 00 00 00  |......ID.3D.....|
00061820  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00061900  28 02 44 bb 49 44 c0 00  00 00 00 00 00 00 00 00  |(.D.ID..........|
00061910  25 f4 ff ff ff ff 00 00  00 00 00 00 00 00 00 00  |%...............|
00061920  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
000619f0  00 00 00 00 00 00 00 00  00 00 24 f0 ff ff ff ff  |..........$.....|
00061a00  00 ff 44 bb 49 44 c0 00  00 00 00 00 00 00 00 00  |..D.ID..........|
00061a10  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00061ae0  00 00 28 ff ff ff ff ff  28 ff ff ff ff ff 28 ff  |..(.....(.....(.|
00061af0  ff ff ff ff 28 ff ff ff  ff ff 28 ff ff ff ff ff  |....(.....(.....|



00061b00  00 ff 85 02 00 43 50 4d  50 4f 4f 4c 2e 30 a0 a0  |.....CPMPOOL.0..|
00061b10  a0 a0 a0 a0 a0 00 00 00  00 00 00 00 00 00 f0 05  |................|
00061b20  00 00 85 29 00 43 50 4d  50 4f 4f 4c 2e 31 a0 a0  |...).CPMPOOL.1..|
00061b30  a0 a0 a0 a0 a0 00 00 00  00 00 00 00 00 00 78 05  |..............x.|
00061b40  00 00 82 01 00 54 45 53  54 52 55 4e a0 a0 a0 a0  |.....TESTRUN....|
00061b50  a0 a0 a0 a0 a0 00 00 00  00 00 00 00 00 00 01 00  |................|
00061b60  00 00 82 01 01 41 54 4f  4d 41 4e 54 49 a0 a0 a0  |.....ATOMANTI...|
00061b70  a0 a0 a0 a0 a0 00 00 00  00 00 00 00 00 00 01 00  |................|
00061b80  00 00 00 01 02 4e 45 57  46 49 4c 45 a0 a0 a0 a0  |.....NEWFILE....|
00061b90  a0 a0 a0 a0 a0 00 00 00  00 00 00 00 00 82 01 00  |................|
00061ba0  00 00 82 01 03 41 54 4f  4d 41 4e 54 49 32 a0 a0  |.....ATOMANTI2..|
00061bb0  a0 a0 a0 a0 a0 00 00 00  00 00 00 00 00 00 01 00  |................|
00061bc0  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|

00061b00  00 ff 85 02 00 43 50 4d  50 4f 4f 4c 2e 30 a0 a0  |.....CPMPOOL.0..|
00061b10  a0 a0 a0 a0 a0 00 00 00  00 00 00 00 00 00 f0 05  |................|

00061b20  00 00 85 29 00 43 50 4d  50 4f 4f 4c 2e 31 a0 a0  |...).CPMPOOL.1..|
00061b30  a0 a0 a0 a0 a0 00 00 00  00 00 00 00 00 00 78 05  |..............x.|


	.BYTE	0, 0			; @0 track/sector of next directory entry [only valid for the very first entry]
	.BYTE	$85 + $40		; @2 file type: "CBM" type + locked flag
	.BYTE	0			; @3 start track
	.BYTE	0			; @4 start sector
	.BYTE	"CP/M DISK POOL /"	; Configuration file
	         CP/M !SYS-DSK! /
	.BYTE	"CP/M DISK POOL 0"	; $5 exactly 16 bytes
             CP/M DISK PART 0
                  DSK-SLICE


	.BYTE	"CP/M DISK POOL 1"



	LDA	pool_str,X
	CMP	sector_buffer,Y
	BNE	@not_our
	INX
	CPX	#16
	BEQ	@found_entry







  Bytes: $00-1F: First directory entry
          00-01: Track/Sector location of next directory sector
             02: File type.
                 Bit 0-3: The actual filetype
                          000 (0) - DEL ($00)
                          001 (1) - SEQ ($81)
                          010 (2) - PRG ($82)
                          011 (3) - USR ($83)
                          100 (4) - REL ($84)
                          101 (5) - CBM ($85, partition or sub-directory)
                          Values 6-15 are illegal, but if used will produce
                          very strange results.
                 Bit   4: Not used
                 Bit   5: Used only during SAVE-@ replacement
                 Bit   6: Locked flag (Set produces ">" locked files)
                 Bit   7: Closed flag  (Not  set  produces  "*", or "splat"
                          files)
                 Typical values for this location are:
                   $00 - Scratched (deleted file entry)
                    80 - DEL
                    81 - SEQ
                    82 - PRG
                    83 - USR
                    84 - REL
                    85 - CBM
          03-04: Track/sector location of first sector of file or partition
          05-14: 16 character filename (in PETASCII, padded with $A0)
          15-16: Track/Sector location of first  SUPER  SIDE  SECTOR  block
                 (REL file only)
             17: REL file record length (REL file only)
          18-1D: Unused (except with GEOS disks)
          1C-1D: (Used during an @SAVE or @OPEN, holds the new t/s link)
          1E-1F: File or partition size in  sectors,  low/high  byte  order
                 ($1E+$1F*256). The  approx.  file  size  in  bytes  is  <=
                 #sectors * 254
          20-3F: Second dir entry. From now on the first two bytes of  each
                 entry in this  sector  should  be  $00/$00,  as  they  are
                 unused.
          40-5F: Third dir entry
          60-7F: Fourth dir entry
          80-9F: Fifth dir entry
          A0-BF: Sixth dir entry
          C0-DF: Seventh dir entry
          E0-FF: Eighth dir entry
"""

