## i8080 CPU emulator and CP/M v2.2 compatible BIOS for MEGA65
##
## Copyright (C)2017,2024 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


DISK_IMAGE	= emu.d81
PRG		= emu.prg
LD65_CFG	= emu.ld
PRG_ON_DISK	= emu
MAP_FILE	= emu.map
SOURCES		= console.asm cpu.asm loader.asm main.asm shell.asm fontdata.asm disk.asm megagw.asm
INCLUDES	= $(shell ls *.inc) cpm/bios.inc cpm/cpm22.inc
OBJECTS		= $(SOURCES:.asm=.o)
M65_IP		= 192.168.0.65
ALL_DEPENDS	= Makefile

CA65_OPTS	= -t none
LD65_OPTS	= -C $(LD65_CFG) -m $(MAP_FILE) -vm

XEMU_M65	= xemu-xmega65
#XEMU_M65	= /home/lgb/prog_here/xemu-dev/build/bin/xmega65.native

ETHERLOAD	= mega65-etherload
C1541		= c1541
CA65		= ca65
LD65		= ld65
RM		= rm
GUNZIP		= gunzip


all: $(DISK_IMAGE)

cpu_tables.inc: cpu_gen_tables.py
	rm -f cpu_tables.inc
	./cpu_gen_tables.py > $@

cpm/bios.inc cpm/cpm22.inc cpm/bios.bin cpm/cpm22.bin:
	$(MAKE) -C cpm

%.o: %.asm $(ALL_DEPENDS) $(INCLUDES)
	$(CA65) $(CA65_OPTS) --listing $(<:.asm=.lst) -o $@ $<

main.o: 8080/*.com 8080/mbasic-real.com

$(PRG): $(OBJECTS) $(LD65_CFG) $(ALL_DEPENDS)
	$(LD65) $(LD65_OPTS) -o $@ $(OBJECTS)

cpm.dsk: diskdefs apps/*.com $(ALL_DEPENDS)
	$(MAKE) -C apps/
	rm -f $@
	mkfs.cpm -f mega65 $@
	cpmcp -f mega65 $@ dist/cpm-apps/* 0:
	cpmcp -f mega65 $@ apps/*.com 0:
	cpmls -f mega65 -D $@

runme.bin: runme.asm
	cl65 -t none -o $@ $<

$(DISK_IMAGE): $(PRG) runme.bin cpm.dsk $(ALL_DEPENDS)
	$(RM) -f $@
	echo "format lgb-test,00 d81 $@\nwrite runme.bin runme\nwrite $(PRG) $(PRG_ON_DISK)\nwrite cpm.dsk\ndir\n" | $(C1541)

ethertest: $(PRG) $(ALL_DEPENDS)
	$(ETHERLOAD) $(M65_IP) $(PRG)

xemu:	$(PRG) $(DISK_IMAGE)
	$(XEMU_M65) -hyperserialfile serial.raw -fastboot -8 $(DISK_IMAGE) -initattic cpm.dsk -prg $(PRG)

dist:	$(DISK_IMAGE)
	cp emu.d81 dist/bin/mega65.d81

clean:
	$(RM) -f $(PRG) *.o *.lst $(DISK_IMAGE) $(MAP_FILE) runme.bin cpm.dsk
	$(MAKE) -C cpm clean
	$(MAKE) -C apps clean

distclean:
	$(MAKE) clean
	$(RM) -f 8080/*.com uart.sock dump.mem serial.raw

.PHONY: all clean distclean xemu ethertest dist
