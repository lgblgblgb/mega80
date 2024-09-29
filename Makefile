## Software i8080 and CP/M emulator for MEGA65
##
## Copyright (C)2017 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
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
SOURCES		= console.asm cpu.asm loader.asm main.asm shell.asm fontdata.asm
INCLUDES	= $(shell ls *.inc) cpm/bios.inc cpm/cpm22.inc
OBJECTS		= $(SOURCES:.asm=.o)
M65_IP		= 192.168.0.65
ALL_DEPENDS	= Makefile

CA65_OPTS	= -t none
LD65_OPTS	= -C $(LD65_CFG) -m $(MAP_FILE) -vm

XEMU_M65	= xemu-xmega65

ETHERLOAD	= mega65-etherload
C1541		= c1541
CA65		= ca65
LD65		= ld65
WGET		= wget
RM		= rm
GUNZIP		= gunzip


all: $(DISK_IMAGE)

cpu_tables.inc: cpu_gen_tables.py
	rm -f cpu_tables.inc
	./cpu_gen_tables.py > $@

cpm/bios.inc cpm/cpm22.inc cpm/bios.bin cpm/cpm22.bin:
	$(MAKE) -C cpm

%.o: %.asm $(ALL_DEPENDS) $(INCLUDES)
	$(CA65) $(CA65_OPTS) -o $@ $<

8080/mbasic-real.com:
	mkdir -p 8080
	$(WGET) -O $@ http://github.lgb.hu/xemu/files/mbasic-real.com

main.o: 8080/*.com 8080/mbasic-real.com

$(PRG): $(OBJECTS) $(LD65_CFG) $(ALL_DEPENDS)
	$(LD65) $(LD65_OPTS) -o $@ $(OBJECTS)

$(DISK_IMAGE): $(PRG) $(ALL_DEPENDS)
	$(RM) -f $@
	echo "format lgb-test,00 d81 $@\nwrite $(PRG) $(PRG_ON_DISK)" | $(C1541)

ethertest: $(PRG) $(ALL_DEPENDS)
	$(ETHERLOAD) $(M65_IP) $(PRG)

xemu:	$(PRG)
	$(XEMU_M65) -fastboot -prg $(PRG)

clean:
	$(RM) -f $(PRG) *.o $(DISK_IMAGE) $(MAP_FILE)
	$(MAKE) -C cpm clean

distclean:
	$(MAKE) clean
	$(RM) -f 8080/*.com uart.sock dump.mem

.PHONY: all clean distclean xemu ethertest
