; CP/M v2.2 compatible CBIOS for MEGA65 running i8080 emulator
; It's only a wrapper more or less, the real work is in MEGA65 assembly.
; (C)2024 LGB Gabor Lenart

	INCLUDE "cpm22.inc"
	ORG	M65BDOS_END_BDOS
BIOS_START_ADDRESS:
	; Note: these (with the HALTs) must be at the beginning of the source and must fit into 256 bytes!
ALL_CALLS	= 17
	; -----------------
	JP	halt_tab + 0	; BIOS_BOOT
	JP	halt_tab + 1	; BIOS_WBOOT
	JP	halt_tab + 2	; BIOS_CONST
	JP	halt_tab + 3	; BIOS_CONIN
	JP	halt_tab + 4	; BIOS_CONOUT
	JP	halt_tab + 5	; BIOS_LIST
	JP	halt_tab + 6	; BIOS_PUNCH
	JP	halt_tab + 7	; BIOS_READER
	JP	halt_tab + 8	; BIOS_HOME
	JP	halt_tab + 9	; BIOS_SELDSK
	JP	halt_tab + 10	; BIOS_SETTRK
	JP	halt_tab + 11	; BIOS_SETSEC
	JP	halt_tab + 12	; BIOS_SETDMA
	JP	halt_tab + 13	; BIOS_READ
	JP	halt_tab + 14	; BIOS_WRITE
	JP	halt_tab + 15	; BIOS_PRSTAT
	JP	halt_tab + 16	; BIOS_SECTRN
	; -----------------

	ASSERT	$ - BIOS_START_ADDRESS = ALL_CALLS * 3, Bad BIOS address jump table being too short or too large.

; HALT causes the i8080 emulator to run native code for the BIOS call (calculated from the i8080 program counter
; offset from "halt_tab"). The emulator is also responsible to do a "RET" operation as its own, so that's why
; you can't see those there. The BIOS handler then examines/uses and modifies CPU registers or even the i8080
; memory, if needed.

halt_tab:
	HALT	; BIOS_BOOT
	HALT	; BIOS_WBOOT
	HALT	; BIOS_CONST
	HALT	; BIOS_CONIN
	HALT	; BIOS_CONOUT
	HALT	; BIOS_LIST
	HALT	; BIOS_PUNCH
	HALT	; BIOS_READER
	HALT	; BIOS_HOME
	HALT	; BIOS_SELDSK
	HALT	; BIOS_SETTRK
	HALT	; BIOS_SETSEC
	HALT	; BIOS_SETDMA
	HALT	; BIOS_READ
	HALT	; BIOS_WRITE
	HALT	; BIOS_PRSTAT
	HALT	; BIOS_SECTRN

	ASSERT	$ - BIOS_START_ADDRESS = ALL_CALLS * 4, Bad BIOS fake op table being too short or too large.

; ------------------------------------------------------------



; ------ END OF BIOS, DO NOT MODIFY ANYTHING AFTER THIS ------

BIOS_END_ADDRESS:

	ASSERT BIOS_END_ADDRESS > BIOS_START_ADDRESS, BIOS placement anomaly.
	ASSERT BIOS_END_ADDRESS <= 0x10000, BIOS overflow at 64K.
	ASSERT (BIOS_START_ADDRESS & 0xFF) = 0, BIOS is not aligned to 256 byte boundary.

MAX_DRIVES = 1
STACK_SIZE = 128		; max space for stack

;                 /---------- drives -----------\                /----< one WORD for MEGA65 special calls at $FFFF
BUFFERS_RESERVE = (MAX_DRIVES * (16 + 128)) + 128 + STACK_SIZE + 2

M65BIOS_START_BIOS = BIOS_START_ADDRESS
M65BIOS_END_BIOS = BIOS_END_ADDRESS
M65BIOS_SIZE_BIOS = BIOS_END_ADDRESS - BIOS_START_ADDRESS
M65BIOS_HALT_TAB_LO = halt_tab & 0xFF
M65BIOS_MAX_DRIVES = MAX_DRIVES
M65BIOS_BUFFER_SPACE = BUFFERS_RESERVE
M65BIOS_WASTED_PAGES = (0x10000 - BIOS_END_ADDRESS - 1 - BUFFERS_RESERVE) >> 8
M65BIOS_ALL_CALLS = ALL_CALLS

M65BIOS_STACK = BIOS_END_ADDRESS + STACK_SIZE
M65BIOS_DRIVE_STRUCTS = M65BIOS_STACK


