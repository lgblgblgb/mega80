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

.DEFINE BIOS_COPYRIGHT "MEGA65 CBIOS for CPM v2.2 (C)2017,2024 LGB Gabor Lenart"

.INCLUDE "mega65.inc"
.INCLUDE "emu.inc"
.INCLUDE "console.inc"
.INCLUDE "cpu.inc"
.INCLUDE "cpm/cpm22.inc"
.INCLUDE "cpm/bios.inc"


.SEGMENT "PAYLOAD"


; These must be exactly next to each other in exactly this order:
bdos_image:	.INCBIN	"cpm/cpm22.bin"
bios_image:	.INCBIN "cpm/bios.bin"


.ZEROPAGE

cpm_dma:	.RES 2
cpm_zp_ptr32:	.RES 4
disk_sector:	.RES 2
disk_track:	.RES 2

.CODE



.PROC	fatal_error
	JSR	write_crlf
	JSR	reg_dump
	; TODO: add "press a key" and option to boot instead of wboot
	WRISTR  {"WBOOT on fatal error",13,10}
:	INC	$D020
	JMP	:-
	JMP	BIOS_WBOOT
.ENDPROC


.PROC	return_cpu_unimplemented
	WRISTR  {13,10,"*** Unimp'd opcode"}
	JMP	fatal_error
.ENDPROC


; Input: depends on the PC value of the i8080 emulator only!
.EXPORT	return_cpu_leave
.PROC	return_cpu_leave
	LDA	cpu_pch
	CMP	#.HIBYTE(M65BIOS_START_BIOS)
	BNE	@not_halt_tab
	LDA	cpu_pcl
	SEC
	SBC	#M65BIOS_HALT_TAB_LO
	CMP	#M65BIOS_ALL_CALLS
	BCS	@bad_halt_ofs
	ASL	A
	TAX
	JMP	(@bios_call_table,X)
@not_halt_tab:
	WRISTR	{13,10,"*** Emu trap not on BIOS gw page / unexpected HALT opcode"}
	JMP	fatal_error
@bad_halt_ofs:
	PHA
	WRISTR	{13,10,"*** Invalid BIOS call #$"}
	PLA
	JSR	write_hex_byte
	JMP	fatal_error
@bios_call_table:
	.WORD	BIOS_BOOT,   BIOS_WBOOT,  BIOS_CONST,  BIOS_CONIN
	.WORD	BIOS_CONOUT, BIOS_LIST,   BIOS_PUNCH,  BIOS_READER
	.WORD	BIOS_HOME,   BIOS_SELDSK, BIOS_SETTRK, BIOS_SETSEC
	.WORD	BIOS_SETDMA, BIOS_READ,   BIOS_WRITE,  BIOS_PRSTAT
	.WORD	BIOS_SECTRN
.ENDPROC


; *** Common part of BOOT and WBOOT

.PROC	go_cpm
	LDA	#$C3		; "JP" opcode
	LDZ	#0
	STA32Z  cpm_zp_ptr32		; @0
	INZ
	LDA	#.LOBYTE(M65BIOS_START_BIOS + 3)
	STA32Z	cpm_zp_ptr32		; @1
	INZ
	LDA	#.HIBYTE(M65BIOS_START_BIOS + 3)
	STA32Z	cpm_zp_ptr32		; @2

	LDA	#$C3		; "JP" opcode - again
	LDZ	#5
	STA32Z	cpm_zp_ptr32		; @5
	INZ
	LDA	#.LOBYTE(M65BDOS_FBASE)
	STA32Z	cpm_zp_ptr32		; @6
	INZ
	LDA	#.HIBYTE(M65BDOS_FBASE)
	STA32Z	cpm_zp_ptr32		; @7

	LDA	#$80
	STA	cpm_dma
	LDA	#$00
	STA	cpm_dma+1
	STA	cpu_c			; C=0 -> drive number [with multiple drives it won't preserve current drive this way!]


	; Set SP to $FFFF
	LDA	#$FF
	STA	cpu_spl
	STA	cpu_sph
	; Set PC to M65BDOS_CBASE (label CBASE in CPM22.ASM = entry point of CCP)
	LDA	#.LOBYTE(M65BDOS_CBASE)
	STA	cpu_pcl
	LDA	#.HIBYTE(M65BDOS_CBASE)
	STA	cpu_pch
	; Start the CPU emulation now
	JMP	cpu_start
.ENDPROC

; --------------------------------------------------------
; BIOS_BOOT: Cold boot of CP/M
; --------------------------------------------------------

.PROC	BIOS_BOOT
	; Fancy printouts
	WRISTR	{CPU_EMU_COPYRIGHT,13,10,BIOS_COPYRIGHT,13,10,"CP/M: "}
	LDX	#0
:	LDA	bdos_image+8,X		; copyright message inside the BDOS
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
	.WORD	M65BDOS_SIZE_BDOS + M65BIOS_SIZE_BIOS	; DMA operation length
	.WORD	bdos_image				; source addr
	.BYTE	0					; source bank + other info
	.WORD	M65BDOS_START_BDOS			; target addr
	.BYTE	I8080_BANK				; target bank + other info
	.WORD	0					; modulo: not used
	LDZ	#0
	; Set up CP/M zero-page (not to be confused with 65xx zero page ...)
	STZ	cpm_zp_ptr32
	STZ	cpm_zp_ptr32+1
	STZ	cpm_zp_ptr32+3
	LDA	#I8080_BANK
	STA	cpm_zp_ptr32+2
	; To have some default anyway
	STZ	disk_sector
	STZ	disk_sector+1
	STZ	disk_track
	STZ	disk_track+1






;	:	INC	$D020
;		JMP	:-
	JMP	go_cpm
.ENDPROC

START_CPM = BIOS_BOOT
.EXPORT START_CPM

; --------------------------------------------------------
; BIOS_WBOOT: Warm boot of CP/M
;             Only reloads CCP and BDOS (not BIOS)
; --------------------------------------------------------

.PROC	BIOS_WBOOT
	JMP	go_cpm
.ENDPROC

.PROC	BIOS_CONST
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_CONIN
.ENDPROC

.PROC	BIOS_CONOUT
	LDA	cpu_c			; character to display in 8080 register 'C'
	JSR	write_char
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_LIST
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_PUNCH
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_READER
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SECTRN: Set track zero
; --------------------------------------------------------

.PROC	BIOS_HOME
	LDA	#0
	STA	disk_track
	STA	disk_track+1
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_SELDSK
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SECTRN: Set track for disk-IO according to BC
; --------------------------------------------------------

.PROC	BIOS_SETTRK
	LDA	cpu_c
	STA	disk_track
	LDA	cpu_b
	STA	disk_track+1
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SETSEC: Set sector for disk-IO according to BC
; --------------------------------------------------------

.PROC	BIOS_SETSEC
	LDA	cpu_c
	STA	disk_sector
	LDA	cpu_b
	STA	disk_sector+1
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SETDMA: Set CP/M DMA according to register BC
; --------------------------------------------------------

.PROC	BIOS_SETDMA
	LDA	cpu_c
	STA	cpm_dma
	LDA	cpu_b
	STA	cpm_dma+1
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_READ
	; Read attic RAM for now ...
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_WRITE
	; Write attic RAM for now ...
	JMP	cpu_start_with_ret
.ENDPROC

.PROC	BIOS_PRSTAT
	JMP	cpu_start_with_ret
.ENDPROC

; --------------------------------------------------------
; BIOS_SECTRN: Sector translation
;              Input: BC
;              Output: HL (we give back BC, for 1:1 skew)
; --------------------------------------------------------

.PROC	BIOS_SECTRN
	; HL := BC
	LDA	cpu_b
	STA	cpu_h
	LDA	cpu_c
	STA	cpu_l
	JMP	cpu_start_with_ret
.ENDPROC
