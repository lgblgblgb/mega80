; ----------------------------------------------------------------------------
;
; Software emulator of the 8080 CPU for the MEGA65, intended for CP/M or such.
; Please read comments throughout this source for more information.
;
; Copyright (C)2017,2024 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
;
; ----------------------------------------------------------------------------
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; Please note: this is *NOT* a Z80 emulator, but a 8080. Still, I
; prefer the Z80 style assembly syntax over 8080, so don't be
; surpised.
;
; ----------------------------------------------------------------------------

.DEFINE MEGA80_COPYRIGHT	"MEGA/80: i8080 emulator and CP/M BIOS for MEGA65 (C)2017,2024 LGB Gabor Lenart"
.DEFINE BIOS_COPYRIGHT		"MEGA65 CBIOS for CP/M v2.2 (C)2017,2024 LGB Gabor Lenart"

.INCLUDE "mega65.inc"
.INCLUDE "emu.inc"
.INCLUDE "console.inc"
.INCLUDE "cpu.inc"
.INCLUDE "cpm/cpm22.inc"
.INCLUDE "cpm/bios.inc"
.INCLUDE "disk.inc"


.SEGMENT "PAYLOAD"


; These must be exactly next to each other in exactly this order:
bdos_image:	.INCBIN	"cpm/cpm22.bin"
bios_image:	.INCBIN "cpm/bios.bin",0,M65BIOS_NONBSS_SIZE


.CODE



.PROC	fatal_error
	JSR	write_crlf
	JSR	reg_dump
	; TODO: add "press a key" and option to boot instead of wboot
	WRISTR  {"WBOOT on fatal error",13,10}
	JMP	BIOS_WBOOT
.ENDPROC


.EXPORT	return_cpu_unimplemented
.PROC	return_cpu_unimplemented
	WRISTR  {13,10,"*** Unimp'd opcode"}
	JMP	fatal_error
.ENDPROC


; Input: depends on the PC value of the i8080 emulator only!
.EXPORT	return_cpu_leave
.PROC	return_cpu_leave
	LDA	cpu_pch
	AND	cpu_pcl
	CMP	#$FF
	BEQ	mega65_special
	LDA	cpu_pch
	CMP	#.HIBYTE(M65BIOS_START_BIOS)
	BNE	not_halt_tab
	LDA	cpu_pcl
	SEC
	SBC	#M65BIOS_HALT_TAB_LO
	CMP	#M65BIOS_ALL_CALLS
	BCS	bad_halt_ofs
	ASL	A
	TAX
	JMP	(bios_call_table,X)
not_halt_tab:
	WRISTR	{13,10,"*** Emu trap not on BIOS gw page / unexpected HALT opcode"}
	JMP	fatal_error
bad_halt_ofs:
	PHA
	WRISTR	{13,10,"*** Invalid BIOS call #$"}
	PLA
	JSR	write_hex_byte
	JMP	fatal_error
mega65_special:
	.IMPORT	megagw
	JSR	megagw
	LBCC	cpu_start_with_ret
	WRISTR	{13,10,"*** Invalid MEGA-GW call"}
	JMP	fatal_error
bios_call_table:
	.WORD	BIOS_BOOT,   BIOS_WBOOT,  BIOS_CONST,  BIOS_CONIN
	.WORD	BIOS_CONOUT, BIOS_LIST,   BIOS_PUNCH,  BIOS_READER
	.WORD	BIOS_HOME,   BIOS_SELDSK, BIOS_SETTRK, BIOS_SETSEC
	.WORD	BIOS_SETDMA, BIOS_READ,   BIOS_WRITE,  BIOS_PRSTAT
	.WORD	BIOS_SECTRN
.ENDPROC

; *** Common part of BOOT and WBOOT

.PROC	go_cpm
	LDA	#$80
	STA	cpm_dma
	LDA	#I8080_BANK
	STA	cpm_dma+2
	LDA	#$00
	STA	cpm_dma+1
	STA	cpm_dma+3
	STA	cpu_c			; C=0 -> drive number [with multiple drives it won't preserve current drive this way!]
	; Routine M65BIOS_GO_CPM will set up the BIOS and BDOS "JP" opcodes on CP/M zero page and execute CBASE (CCP)
	LDA	#.LOBYTE(M65BIOS_GO_CPM)
	STA	cpu_pcl
	LDA	#.HIBYTE(M65BIOS_GO_CPM)
	STA	cpu_pch
	RTS
.ENDPROC

; --------------------------------------------------------
; BIOS_BOOT: Cold boot of CP/M
; --------------------------------------------------------

.PROC	BIOS_BOOT
	JSR	console_state_reset
	; Fancy printouts
	.IMPORT	build_info_str
	LDX	#0
:	LDA	build_info_str,X
	BEQ	:+
	JSR	write_char
	INX
	BNE	:-
:	JSR	write_crlf
	WRISTR	{CPU_EMU_COPYRIGHT,13,10,BIOS_COPYRIGHT,13,10,"CCP and BDOS "}
	LDX	#0
:	LDA	bdos_image+8,X		; DR's copyright message inside the BDOS: let's print that out as well!
	BEQ	:+
	JSR	write_char
	INX
	BNE	:-
:	JSR	write_crlf
	; Initialize all memory to zero and copy CCP+BDOS+BIOS to place with DMA
	STA	$D707					; trigger in-line DMA
	.BYTE	$A,0					; --- first job --- enhanced mode opts
	.BYTE	3 + 4					; DMA command: fill AND chained!
	.WORD	0					; DMA length: 0 should mean 64K
	.WORD	0					; source addr, in case of "fill" the low byte is the byte to fill with
	.BYTE	0					; source bank + other info
	.WORD	0					; target addr
	.BYTE	I8080_BANK				; target bank + other info
	.WORD	0					; modulo: not used
	.BYTE	$A,0					; --- second job --- enhanced mode opts
	.BYTE	0					; DMA command, and other info, here: copy op, not chained!!!
	.WORD	M65BDOS_SIZE_BDOS + M65BIOS_NONBSS_SIZE	; DMA operation length
	.WORD	bdos_image				; source addr
	.BYTE	0					; source bank + other info
	.WORD	M65BDOS_START_BDOS			; target addr
	.BYTE	I8080_BANK				; target bank + other info
	.WORD	0					; modulo: not used
	; To have some default anyway
	LDZ	#0
	STZ	disk_sector
	STZ	disk_sector+1
	STZ	disk_track
	STZ	disk_track+1
	;
	JSR	go_cpm
	JSR	write_inline_string
		.BYTE	"MEM:"
		.INCLUDE "cpm/info.inc"
		.BYTE	13,10,0
	JMP	cpu_start
.ENDPROC


; --------------------------------------------------------
; BIOS_WBOOT: Warm boot of CP/M
;             Only reloads CCP and BDOS (not BIOS)
; --------------------------------------------------------

.PROC	BIOS_WBOOT
	JSR	console_state_reset
	; Copy BDOS/CCP only (not the BIOS itself!)
	STA	$D707					; trigger in-line DMA
	.BYTE	$A,0					; --- second job --- enhanced mode opts
	.BYTE	0					; DMA command, and other info, here: copy op, not chained!!!
	.WORD	M65BDOS_SIZE_BDOS			; DMA operation length
	.WORD	bdos_image				; source addr
	.BYTE	0					; source bank + other info
	.WORD	M65BDOS_START_BDOS			; target addr
	.BYTE	I8080_BANK				; target bank + other info
	.WORD	0					; modulo: not used
	JSR	go_cpm
	JMP	cpu_start
.ENDPROC

; --------------------------------------------------------
; BIOS_CONST: Check console status
;             Input:  -
;             Output: A=0 no char, A=$FF char available
; --------------------------------------------------------
.PROC	BIOS_CONST
	JSR	conin_check_status
	STA	cpu_a
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_CONIN: Get character from console (with waiting)
;             Input:  -
;             Output: A = character
; --------------------------------------------------------
.PROC	BIOS_CONIN
	JSR	conin_get_with_wait
	STA	cpu_a
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_CONOUT: Display character
;              Input:  C = character
;              Output: -
; --------------------------------------------------------

.PROC	BIOS_CONOUT
	LDA	cpu_c			; character to display in 8080 register 'C'
	JSR	write_char
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_LIST
	; Nothing to do, just return [TODO: sure?]
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_PUNCH
	; Nothing to do, just return
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_READER
	; Return with $1A in A
	LDA	#$1A
	STA	cpu_a
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SECTRN: Set selected track to zero
;              Input:  -
;              Output: -
; --------------------------------------------------------

.PROC	BIOS_HOME
	LDA	#0
	STA	disk_track
	STA	disk_track+1
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SELDSK: Select disk
;              Input:  C = drive to select
;              Output: HL = BIOS disk struct OR zero (error)
; --------------------------------------------------------

.PROC	BIOS_SELDSK
	LDA	cpu_c
	BNE	error		; currently one drive is supported (drive zero) only, thus non-zero value is an error
	LDA	#.LOBYTE(M65BIOS_DPH)
	STA	cpu_l
	LDA	#.HIBYTE(M65BIOS_DPH)
	STA	cpu_h
	JMP	cpu_start_with_ret
error:
	LDA	#0
	STA	cpu_l
	STA	cpu_h
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SECTRN: Set track for disk I/O
;              Input:  BC = select track number
;              Output: -
; --------------------------------------------------------

.PROC	BIOS_SETTRK
	LDA	cpu_c
	STA	disk_track
	LDA	cpu_b
	STA	disk_track+1
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SETSEC: Set sector for disk I/O
;              Input:  BC = select sector number
;              Output: -
; --------------------------------------------------------

.PROC	BIOS_SETSEC
	LDA	cpu_c
	STA	disk_sector
	LDA	cpu_b
	STA	disk_sector+1
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SETDMA: Set CP/M DMA
;              Input:  BC = address of DMA area to set
;              Output: -
; --------------------------------------------------------

.PROC	BIOS_SETDMA
	LDA	cpu_c
	STA	cpm_dma
	LDA	cpu_b
	STA	cpm_dma+1
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_READ: Read sector from disk
;            Input:  -
;            Output: A = opresult: 0=OK, 1=ERROR
; --------------------------------------------------------

.PROC	BIOS_READ
	JSR	disk_read
	STA	cpu_a
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_WRITE: Write sector to disk
;             Input:  C = deblocking info
;                         0 = normal sector write
;                         1 = write to directory sector
;                         2 = write to the first sector of a new data block
;             Output: A = opresult: 0=OK, 1=ERROR
; --------------------------------------------------------

.PROC	BIOS_WRITE
	JSR	disk_write
	STA	cpu_a
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_PRSTAT
	LDA	#0	; "not ready"
	STA	cpu_a
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SECTRN: Sector translation
;              Input:  BC = sector number
;              Output: HL = translated sector number
; We give back BC, for 1:1 skew aka "no skew"
; --------------------------------------------------------

.PROC	BIOS_SECTRN
	; HL := BC
	LDA	cpu_b
	STA	cpu_h
	LDA	cpu_c
	STA	cpu_l
	JMP	cpu_start_with_ret
.ENDPROC

; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------

.IF	INSPECTOR_SHELL = 1
	.IMPORT	command_processor
.ELSE
	command_processor:
		RTS
.ENDIF

; This is the "main function" jumped by the loader
.EXPORT	app_main
.PROC	app_main
	LDA	#5			; All RAM but I/O
	STA	1
	JSR	init_console		; that will also set up IRQ and NMI
	JSR	clear_screen		; the fist call of this initiailizes console out functions
	WRISTR	{MEGA80_COPYRIGHT,13,10,"M65 OS/DOS versions are "}
	LDA	#0
	HYPERDOS
	JSR	write_hex_byte
	TXA
	JSR	write_hex_byte
	LDA	#32
	JSR	write_char
	TYA
	JSR	write_hex_byte
	TZA
	JSR	write_hex_byte
	JSR	write_crlf
	JSR	cpu_reset
	CLI				; beware, interrupts are enabled :-)
	JSR	command_processor	; call the inspector shell before starting - if enabled in config
	JMP	BIOS_BOOT
.ENDPROC
