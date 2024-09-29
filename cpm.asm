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


.CODE


.PROC	cpm_copy
	STA	$D707					; trigger in-line DMA
	.BYTE	$A,0					; enhanced mode opts
	.BYTE	3					; DMA command, and other info, here: copy op
size:	.WORD	M65BDOS_SIZE_BDOS + M65BIOS_SIZE_BIOS	; DMA operation length
	.WORD	bdos_image				; source addr
	.BYTE	0					; source bank + other info
	.WORD	M65BDOS_START_BDOS			; target addr
	.BYTE	I8080_BANK				; target bank + other info
	.WORD	0					; modulo: not used
	; Next time only copy the BDOS
	LDA	#.LOBYTE(M65BDOS_SIZE_BDOS)
	STA	size
	LDA	#.HIBYTE(M65BDOS_SIZE_BDOS)
	STA	size + 1
	RTS
.ENDPROC


.PROC	cpm_install
	; Clear the whole bank of memory just to be safe
	STA	$D707					; trigger in-line DMA
	.BYTE	$A,0					; enhanced mode opts
	.BYTE	0					; DMA command: fill
	.WORD	M65BDOS_START_BDOS			; DMA length: we only clear up to the start of BDOS which will be copied below
	.WORD	0					; source addr, in case of "fill" the low byte is the byte to fill with
	.BYTE	0					; source bank + other info
	.WORD	0					; target addr
	.BYTE	I8080_BANK				; target bank + other info
	.WORD	0					; modulo: not used
	; Install BDOS (including CPP) and BIOS
	; The "cpm_copy_ routine modifies itself then to copy only the BDOS next time!
	JSR	cpm_copy
.ENDPROC


bios_call_table:
	.WORD BIOS_BOOT,   BIOS_WBOOT,  BIOS_CONST,  BIOS_CONIN
	.WORD BIOS_CONOUT, BIOS_LIST,   BIOS_PUNCH,  BIOS_READER
	.WORD BIOS_HOME,   BIOS_SELDSK, BIOS_SETTRK, BIOS_SETSEC
	.WORD BIOS_SETDMA, BIOS_READ,   BIOS_WRITE,  BIOS_PRSTAT
	.WORD BIOS_SECTRN



.PROC	return_cpu_unimplemented
.ENDPROC


; Input: depends on the PC value of the i8080 emulator only!
.EXPORT	bios_call
.PROC	bios_call
	LDA	cpu_pch
	CMP	#.HIBYTE(M65BIOS_START_BIOS)
	BNE	@not_halt_tab
	LDA	cpu_pcl
	SEC
	SBC	#M65BIOS_HALT_TAB_LO
	CMP	#M65BIOS_ALL_CALS
	BCS	@not_halt_tab
	ASL	A
	TAX
	JMP	(bios_call_table,X)
@not_halt_tab:
	WRISTR	{13,10,"*** Emulation trap not on the BIOS or BDOS pages",13,10}
.ENDPROC


.PROC	BIOS_CONOUT
	LDA	cpu_c
	JMP	write_char
.ENDPROC



