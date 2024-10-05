ASM80		= sjasmplus --nologo --msg=war --i8080 --fullpath --color=auto

SOURCES		= $(shell ls *.asm)
#INCLUDES	= $(shell ls *.inc)
INCLUDES	=
PROGRAMS	= $(SOURCES:.asm=.com)


all: $(PROGRAMS)


%.com: %.asm Makefile $(INCLUDES)
	@echo "----[ Assembling CP/M app $< --> $@ ]----"
	rm -f $@ $(@)2
	$(ASM80) --raw=$(@)2 $<
	mv $(@)2 $@

clean:
	rm -f *.com *.com2 *.sym *.lst *.map

.PHONY: all clean
