#!/usr/bin/env python

import sys,math


"""
diskdef mega65
  seclen 128
  tracks 16
  sectrk 256
  blocksize 2048
  maxdir 256
  skew 1
  boottrk 0
  os 2.2
end
"""

FORMAT = "mega65"
oursection = False
fmt = {}

with open("diskdefs", "rt") as f:
    for line in f:
        l = line.strip().split()
        if len(l) == 2:
            if l[0] == "diskdef" and l[1] == FORMAT:
                if fmt:
                    raise RuntimeError("Multiple definitions with name: {}".format(FORMAT))
                oursection = True
            elif l[0] == "seclen" and oursection:
                fmt["seclen"] = int(l[1])
            elif l[0] == "tracks" and oursection:
                fmt["tracks"] = int(l[1])
            elif l[0] == "sectrk" and oursection:
                fmt["sectrk"] = int(l[1])
            elif l[0] == "blocksize" and oursection:
                fmt["blocksize"] = int(l[1])
            elif l[0] == "maxdir" and oursection:
                fmt["maxdir"] = int(l[1])
            elif l[0] == "skew" and oursection:
                fmt["skew"] = int(l[1])
            elif l[0] == "boottrk" and oursection:
                fmt["boottrk"] = int(l[1])
            elif l[0] == "os" and oursection:
                fmt["os"] = l[1]
        elif len(l) > 0 and l[0] == "end":
            oursection = False

if oursection:
    raise RuntimeError("Unclosed definition")
if not fmt:
    raise RuntimeError("Missing definition: {}".format(FORMAT))

for a in ("seclen", "tracks", "sectrk", "blocksize", "maxdir", "skew", "boottrk", "os"):
    if a not in fmt:
        raise RuntimeError("Missing '{}'".format(a))
if fmt["skew"] != 1:
    raise RuntimeError("skew must be 1")
if fmt["boottrk"] != 0:
    raise RuntimeError("boottrk must be 0")
if fmt["os"] != "2.2":
    raise RuntimeError("os must be 2.2")
if fmt["seclen"] != 128:
    raise RuntimeError("seclen must be 128")
if fmt["sectrk"] != 256:
    raise RuntimeError("sectrk must be 256")
if fmt["blocksize"] not in (1024, 2048, 4096, 8192, 16384):
    raise RuntimeError("blocksize must be one of these: 1024, 2048, 4096, 8192, 16384")

print(fmt)

a = fmt["blocksize"] // fmt["seclen"]
if fmt["blocksize"] % fmt["seclen"]:
    raise RuntimeError("blocksize/seclen does not give integer")

capacity = (fmt["sectrk"] * fmt["tracks"] * 128) // fmt["blocksize"]

al = fmt["maxdir"] * 32 // fmt["blocksize"]
if fmt["maxdir"] * 32 % fmt["blocksize"]:
    raise RuntimeError("Bad maxdir, maxdir * 32 / blocksize is not integer")


print("DW {}  ; SPT".format(fmt["sectrk"]))
print("DB {}  ; BSH".format(int(round(math.log2(a)))))
print("DB {}  ; BLM".format(a - 1))
print("DB {}  ; EXM".format(1 if capacity >= 256 else 0))
print("DW {}  ; DSM".format(capacity - 1))
print("DW {}  ; DRM".format(fmt["maxdir"] - 1))
print("DB {}  ; AL0".format(-1))
print("DB {}  ; AL1".format(-1))
print("DW ??? ; CKS")
print("DW {}  ; OFF".format(fmt["boottrk"]))


