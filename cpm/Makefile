CPM_START_ADDRESS	= 0xE400
CPM_EXACT_SIZE		= 0x1600

ASM80			= sjasmplus --nologo --msg=war --i8080

all: cpm22.bin bios.bin bios.inc cpm22.inc

cpm22.inc: cpm22.bin cpm22.sym Makefile
	@echo "----[ DR BDOS: extracting symbols ]---"
	@rm -f cpm22.inc
	sed -rn 's/(M65BDOS_[^:]*):.*equ.*0x0*(.*)$$/\1 = $$\2/ip' cpm22.sym | tee cpm22.inc

cpm22.bin: cpm22.asm Makefile
	@echo "----[ DR BDOS: assembling ]----"
	@rm -f cpm22.bin cpm22.lst cpm22.sym cpm22.inc
	$(ASM80) -DCPM_START_ADDRESS=$(CPM_START_ADDRESS) -DCPM_EXACT_SIZE=$(CPM_EXACT_SIZE) --sym=cpm22.sym --raw=cpm22.bin --lst=cpm22.lst cpm22.asm

bios.inc: bios.bin bios.sym Makefile
	@echo "----[ BIOS: extracting i8080 BIOS symbols ]----"
	@rm -f bios.inc
	sed -rn 's/(M65BIOS_[^:]*):.*equ.*0x0*(.*)$$/\1 = $$\2/ip' bios.sym | tee bios.inc

bios.bin: bios.asm cpm22.inc Makefile
	@echo "----[ BIOS: assembling i8080 BIOS ]----"
	@rm -f bios.bin bios.lst bios.sym bios.inc
	$(ASM80) --sym=bios.sym --raw=bios.bin --lst=bios.lst bios.asm

clean:
	rm -f cpm22.bin cpm22.lst cpm22.sym cpm22.inc bios.bin bios.lst bios.sym bios.inc

.PHONY: all clean
