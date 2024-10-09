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
; ----------------------------------------------------------------------------

.INCLUDE "mega65.inc"
.INCLUDE "emu.inc"
.INCLUDE "cpu.inc"
.INCLUDE "console.inc"
.INCLUDE "disk.inc"

GW_BUFFER_SIZE = 1024

.BSS

gw_buffer:	.RES	GW_BUFFER_SIZE
.ASSERT gw_buffer + GW_BUFFER_SIZE < $8000, error, "gw_buffer must be in the low-memory area."

.CODE



.EXPORT	megagw
.PROC	megagw
	LDA	cpu_a
	CMP	#calls
	BCS	ret		; carry is already set for error
	ASL	A
	TAX
	JMP	(jump_table,X)
ret:
	RTS
jump_table:
	.WORD	shutdown		; func  0
	.WORD	get_host_buffer_addr	; func  1
	.WORD	get_info_str		; func  2     will use the CP/M dma!!!
	.WORD	hdos_trap               ; func  3
calls = (* - jump_table) / 2
.ENDPROC


; Format of HDOS call from the viewpoint of CP/M app:
;
; Input AND output register registers:
;       B = host CPU register A
;       C = host CPU register X
;       D = host CPU register Y
;       E = host CPU register Z
; Output:
;	FLAGS = carry SET -> OK, carry CLEAR -> ERROR
; Input register:
;	A = call ID, 0 -> HDOS trap
;	HL = mem address of 256 bytes buffer!
;	Data buffer must be appropiate size for the given call
;
; The call itself must be: CALL $FFFF

.PROC	call_trap
	STA	trap_lo_byte
	LDA	cpu_l
	STA	copy1
	STA	copy2
	LDA	cpu_h
	STA	copy1+1
	STA	copy2+2
	; Copy CP/M buffer for us
	STA	$D707					; trigger in-line DMA
	.BYTE	$A,0					; enhanced mode opts
	.BYTE	0					; DMA command: copy and not chained
	.WORD	GW_BUFFER_SIZE				; DMA length
copy1:	.WORD	0					; source addr, in case of "fill" the low byte is the byte to fill with
	.BYTE	I8080_BANK				; source bank + other info
	.WORD	gw_buffer				; target addr
	.BYTE	0					; target bank + other info
	.WORD	0					; modulo: not used
	; Load 8080 registers into naitve registers for the TRAP
	LDA	cpu_b
	LDX	cpu_c
	LDY	cpu_d
	LDZ	cpu_e
	; The TRAP itself
trap_lo_byte = * + 1
	STA	$D640		; The trap!
	CLV			; MEGA65 safety measure
	; Save resulting native registers to 8080 registers
	STA	cpu_b
	STX	cpu_c
	STY	cpu_d
	STZ	cpu_e
	; Check the carry flag, and transfer it to the 8080 carry flag
	; (this also means that carry shouldn't be bothered between this point - ADC - and the trap itself above!!)
	LDA	cpu_f
	AND	#$FE		; clear 8080 carry flag (bit 0 will be cleared)
	ADC	#0		; if host carry was set, this actually adds 1 (bit 0 will be set), so we're good :D
	STA	cpu_f
	; Copy our buffer to CP/M buffer
	STA	$D707					; trigger in-line DMA
	.BYTE	$A,0					; enhanced mode opts
	.BYTE	0					; DMA command: copy and not chained
	.WORD	GW_BUFFER_SIZE				; DMA length
	.WORD	gw_buffer				; source addr, in case of "fill" the low byte is the byte to fill with
	.BYTE	0					; source bank + other info
copy2:	.WORD	0					; target addr
	.BYTE	I8080_BANK				; target bank + other info
	.WORD	0					; modulo: not used
	; ... and we're done :D
	CLC		; Valid call signal (nothing to do with the carry result of the trap itself!!!)
	RTS
.ENDPROC


.PROC	get_host_buffer_addr
	LDA	#.LOBYTE(gw_buffer)
	STA	cpu_l
	LDA	#.HIBYTE(gw_buffer)
	STA	cpu_h
	CLC
	RTS
.ENDPROC


.PROC	hdos_trap
	LDA	#$40	; trap addr low byte
	JMP	call_trap
.ENDPROC


.PROC	shutdown
	SEI			; Disable interrupts
	LDA	#$FF
	STA	1
	STA	$D02F		; VIC KEY register, let's mess it up
	JMP	($FFFC)
.ENDPROC


.PROC	get_info_str
	.IMPORT	build_info_str
	LDX	#0
	LDZ	#0
:	LDA	build_info_str,X
	STA32Z	cpm_dma
	BEQ	:+
	INX
	INZ
	BRA	:-
:	CLC
	RTS
.ENDPROC

