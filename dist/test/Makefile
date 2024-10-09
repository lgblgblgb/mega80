test.prg: test.asm
	cl65 -t none -o test.prg test.asm

xemu: test.prg
	xemu-xmega65 -prg test.prg

clean:
	rm -f test.prg *.o

.PHONY: xemu clean

