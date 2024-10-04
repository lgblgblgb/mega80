CPMSYS = ../emu.prg
MAXBLOCKS = 100

boot: boot.asm $(CPMSYS) config_maker.py Makefile
	rm -f boot.inc
	python config_maker.py $(CPMSYS) $(MAXBLOCKS) > boot.inc
	cl65 -t none --cpu 4510 --config boot.ld -o boot boot.asm

clean:
	rm -f boot boot.inc *.o

