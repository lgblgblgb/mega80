; Boot code, needs "BOOT SYS" command from BASIC65

.INCLUDE "boot.inc"		; file created by config_maker.py

.CODE

	JMP	boot		; we want to jump over the disk identifier, ALSO "JMP" ($4C opc) is a must for ROM to be recognized!

.BYTE "MC80"			; disk indentifier (at offset 3, we are now) for MEGA65 CP/M

boot:

	RTS

	JMP	LOAD_ADDR	; pass control to the loaded program





.SEGMENT	"PAYLOAD"
.INCBIN		LOAD_BIN_FN, LOAD_OFFSET
.IF		PADDING <> 0
	.RES	PADDING, $00
.ENDIF

