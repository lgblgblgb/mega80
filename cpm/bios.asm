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

M65BIOS_GO_CPM:
	LD	SP, stack_top			; Let's have some stack
	LD	A, 0xC3
	LD	(0), A				; "JP" opcode for BIOS functions
	LD	(5), A				; "JP" opcode for BDOS functions
	LD	HL, BIOS_START_ADDRESS + 3	; Set-up jump address for BIOS functions: pointing to WBOOT and *NOT* BOOT!
	LD	(1), HL
	LD	HL, M65BDOS_FBASE		; Set-up jump address for BDOS functions
	LD	(6), HL
	LD	A, 0x76				; HALT opcode at $FFFF -> special MEGA65 gw for future stuff
	LD	(0xFFFF),A
	JP	M65BDOS_CBASE			; Execute CCP (C register is needed to be initialized by the native BIOS before calling us here!)

; ------------------------------------------------------------

; Terminology is taken from the "Offical CP/M Alteration guide"
; http://www.gaby.de/cpm/manuals/archive/cpm22htm/ch6.htm

; Disk Parameter Header (DPH)
M65BIOS_DPH:
	DW	0		; XLT sector translation table (no xlation done)
	DW	0		; scratchpad
	DW	0		; scratchpad
	DW	0		; scratchpad
	DW	disk_dirbuf	; system-wide, shared DIRBUF pointer
	DW	dpb_table	; DPB (Disk Parameter Block) pointer
	DW	chk		; CSV pointer (optional, not implemented), used for software disk change detection
	DW	alv		; ALV pointer

; Disk Parameter Block (DPB)
dpb_table:
	DW	26		; SPT: total number of sectors per track
	DB	3		; BSH: data allocation block shift factor, determined by the data block allocation size.
	DB	7		; BLM: data allocation block mask (2[BSH-1]).
	DB	0		; EXM: extent mask, determined by the data block allocation size and the number of disk blocks.
	DW	242		; DSM: total storage capacity of the disk drive (max allocation block number)
	DW	63		; DRM: total number of directory entries that can be stored on this drive.
	DB	192		; AL0: determine reserved directory blocks.
	DB	0		; AL1: -- "" ---
	DW	16		; CKS: size of the directory check vector.
	DW	0		; OFF: number of reserved tracks at the beginning of the (logical) disk.


; ------ ONLY UN'INIT'ED stuff can goes here from this point -----

NONBSS_SIZE = $ - BIOS_START_ADDRESS
M65BIOS_NONBSS_SIZE = NONBSS_SIZE


disk_dirbuf:	DS	128
alv:		DS	31
chk:		DS	16
stack:		DS	128
stack_top =	$


BIOS_END_ADDRESS:

	ASSERT BIOS_END_ADDRESS > BIOS_START_ADDRESS, BIOS placement anomaly.
	ASSERT BIOS_END_ADDRESS <= 0x10000, BIOS overflow at 64K.
	ASSERT (BIOS_START_ADDRESS & 0xFF) = 0, BIOS is not aligned to 256 byte boundary.

M65BIOS_START_BIOS = BIOS_START_ADDRESS
M65BIOS_HALT_TAB_LO = halt_tab & 0xFF
M65BIOS_WASTED_PAGES = (0x10000 - BIOS_END_ADDRESS) >> 8
M65BIOS_ALL_CALLS = ALL_CALLS
