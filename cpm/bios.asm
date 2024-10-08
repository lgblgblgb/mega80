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

	; Present a couple of other JPs just in case if a program expects a BIOS which knows more stuff

	JP	halt_tab + 17
	JP	halt_tab + 18
	JP	halt_tab + 19
	JP	halt_tab + 20
	JP	halt_tab + 21
	JP	halt_tab + 22
	JP	halt_tab + 23
	JP	halt_tab + 24
	JP	halt_tab + 25
	JP	halt_tab + 26
	JP	halt_tab + 27
	JP	halt_tab + 28
	JP	halt_tab + 29
	JP	halt_tab + 30
	JP	halt_tab + 31
	JP	halt_tab + 32

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

	ASSERT	$ - halt_tab = ALL_CALLS, Bad BIOS fake op table being too short or too large.

	DB	0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0   ; some further NOPs

	ASSERT  ($ - BIOS_START_ADDRESS) < 0x100, Too long BIOS fake page


;CONIN_HACK:
;	CALL	halt_tab + 2			; call CONST
;	CP	0
;	JP	Z, CONIN_HACK
;	JP	halt_tab + 3			; jump to CONIN

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
	LD	(0xFFFE),A			; guarding HALT
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
	DW	0 ; chk  ; was: chk	; CSV pointer (optional, not implemented), used for software disk change detection: IF NOT used, in DPB the CKS should set to zero.
	DW	alv		; ALV pointer


TRACKS		= 17		; number of tracks
SECTORS		= 256		; sectors per track [currently must be always 256]
BOOTTRACKS	= 0		; reserved tracks for the OS (for booting, etc)
BLOCKSIZE	= 2048		; allocation block size
SECTORSIZE	= 128		; sector size [currently must be always 128]
DIRENTRIES	= 256		; max number of directory entries

	ASSERT	SECTORS = 256, SECTORS must be 256
	ASSERT	SECTORSIZE = 128, SECTORSIZE must be 128

DPB_DSM = SECTORS * TRACKS * SECTORSIZE / BLOCKSIZE

	IF 	BLOCKSIZE = 1024
DPB_BSH = 3
DPB_BLM = 7
	IF	DPB_DSM < 256
DPB_EXM =
	ELSE
DPB_EXM =
	ENDIF
	ENDIF

	IF	BLOCKSIZE = 2048
DPB_BSH = 4
DPB_BLM = 15
	IF	DPB_DSM < 256
DPB_EXM = 1
	ELSE
DPB_EXM = 0
	ENDIF
	ENDIF

	IF	BLOCKSIZE = 4096
DPB_BSH = 5
DPB_BLM = 31
	IF	DPB_DSM < 256
DPB_EXM =
	ELSE
DPB_EXM =
	ENDIF
	ENDIF

	IF	BLOCKSIZE = 8192
DPB_BSH = 6
DPB_BLM = 63
	IF	DPB_DSM < 256
DPB_EXM =
	ELSE
DPB_EXM =
	ENDIF
	ENDIF

	IF	BLOCKSIZE = 16384
DPB_BSH = 7
DPB_BLM = 127
	IF	DPB_DSM < 256
DPB_EXM =
	ELSE
DPB_EXM =
	ENDIF
	ENDIF


	IF 1
; Disk Parameter Block (DPB)
dpb_table:
	DW	256		; SPT: total number of sectors per track aka. logical sectors per track (offset0)
	DB	4		; BSH: data allocation block shift factor, determined by the data block allocation size.
	DB	15		; BLM: data allocation block mask (2[BSH-1]).
	DB	0		; EXM: extent mask, determined by the data block allocation size and the number of disk blocks. ??? 1-> total blocks>255??
	DW	271		; DSM: total storage capacity of the disk drive (max allocation block number) aka. logical disk size-1 in blocks: (sec*track*128)/blocksize-1
	DW	255		; DRM: total number of directory entries that can be stored on this drive MINUS-1
	DB	0xF0		; AL0: determine reserved directory blocks.
	DB	0		; AL1: -- "" ---
	DW	0  ; was 16	; CKS: size of the directory check vector (non-removable media in out case, let's use zero!)
	DW	0		; OFF: number of reserved tracks at the beginning of the (logical) disk. [OFF=OFFset]
	;ENDIF
	ELSE
	;IF 1
dpb_table:
	DW	256		; SPT: total number of sectors per track
	DB	4		; BSH: data allocation block shift factor, determined by the data block allocation size.
	DB	15		; BLM: data allocation block mask (2[BSH-1]).
	DB	0		; EXM: extent mask, determined by the data block allocation size and the number of disk blocks.
	DW	2420		; DSM: total storage capacity of the disk drive (max allocation block number)
	DW	256		; DRM: total number of directory entries that can be stored on this drive.
	DB	0		; AL0: determine reserved directory blocks.
	DB	0		; AL1: -- "" ---
	DW	0		; CKS: size of the directory check vector.
	DW	0		; OFF: number of reserved tracks at the beginning of the (logical) disk.
	ENDIF


; DPB explanation:
; DRM can be any value that when multiplied by 32 fits evenly in an allocation block
; In our case: DRM is 255 which mins 256 entries. When it's multiplied with 32, we get 8192
; that evently fits into 8192/2048=4 allocation blocks (2048 here: the logical block size)
; That also means, this 4 must be used for the "AL" fields but in a very odd way:
; AL0 must be $F0, and AL1 is $0 (since the result means the number of bits to set ....)


; ------ ONLY UN'INIT'ED stuff can goes here from this point -----

NONBSS_SIZE = $ - BIOS_START_ADDRESS
M65BIOS_NONBSS_SIZE = NONBSS_SIZE


disk_dirbuf:	DS	128
; alv size must be:  (DSM/8) + 1
alv:		DS	35
chk:		DS	16
stack:		DS	16
stack_top =	$


BIOS_END_ADDRESS:

	ASSERT BIOS_END_ADDRESS > BIOS_START_ADDRESS, BIOS placement anomaly.
	ASSERT BIOS_END_ADDRESS <= 0x10000, BIOS overflow at 64K.
	ASSERT (BIOS_START_ADDRESS & 0xFF) = 0, BIOS is not aligned to 256 byte boundary.

M65BIOS_START_BIOS = BIOS_START_ADDRESS
M65BIOS_HALT_TAB_LO = halt_tab & 0xFF
M65BIOS_WASTED_PAGES = (0x10000 - BIOS_END_ADDRESS) >> 8
M65BIOS_ALL_CALLS = ALL_CALLS
