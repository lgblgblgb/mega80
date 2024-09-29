#!/usr/bin/env python

import sys

if len(sys.argv) != 3:
    raise RuntimeError("Bad usage.")

filename, block_limit = sys.argv[1:]

block_limit = int(block_limit)

with open(filename, "rb") as prg:
    prg = prg.read()
if len(prg) < 20:
    raise RuntimeError("Abnormally short PRG file")
if prg[0] != 0x01 or prg[1] != 0x20:
    raise RuntimeError("Not a valid MEGA65 BASIC-stub PRG")
i = prg.find(b'\x00\x00\x00')
if i == -1:
    raise RuntimeError("End of BASIC-stub cannot be found")
if i < 10 or i > 100:
    raise RuntimeError("Unusual index ({}) for BASIC-stub end".format(i))
i += 3

b = (len(prg) - i) // 0x200
if  (len(prg) - i) %  0x200:
    b += 1

if b > block_limit:
    raise RuntimeError("Boot data is {} blocks long, max allowed size is {} blocks.".format(b, block_limit))

print("LOAD_ADDR = {}".format(i + 0x2001))
print("LOAD_SIZE_BYTES = {}".format(len(prg) - i))
print("LOAD_SIZE_BLOCKS = {}".format(b))
print("LOAD_OFFSET = {}".format(i))
print("PADDING = {}".format(0x200 - (len(prg) - i) %  0x200))
print(".DEFINE LOAD_BIN_FN \"{}\"".format(filename))

