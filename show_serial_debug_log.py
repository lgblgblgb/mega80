#!/usr/bin/env python3

import sys

HEXDUMPINDEX = 11

def add_asm ( db, line, prefix ):
    #  012345678901
    # |  50  E400 C3 5C E7     CBASE:  JP      COMMAND         ;execute command processor (ccp).|
    line = line.rstrip()
    if line.startswith("#") or len(line) <= HEXDUMPINDEX or line[HEXDUMPINDEX] in (' ', '\t'):
        return
    #print(line[HEXDUMPINDEX], line)
    l = line.split()
    a = int(l[1], 16)
    if db[a] == "":
        db[a] = "[" + prefix + "] " + line

asm = [""] * 0x10000

# Load assembly source info
with open("cpm/bios.lst", "rt") as f:
    for line in f:
        add_asm(asm, line, "BIOS")
with open("cpm/cpm22.lst", "rt") as f:
    for line in f:
        add_asm(asm, line, "CPM ")


#print(asm)
#sys.exit(0)



with open("serial.raw", "rb") as raw:
    raw = raw.read()

while len(raw) > 1:
    addr = raw[0] + (raw[1] << 8)
    raw = raw[2:]
    #haddr = "{:04X}".format(addr)
    #line = asm[haddr] if haddr in asm else "?"
    print("{:04X} -> {}".format(addr, asm[addr]))


