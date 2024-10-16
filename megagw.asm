; ----------------------------------------------------------------------------
; vi: ft=ca65
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

HDOS_BUFFER = $400

.BSS

fd_dir:		.RES	1
fd_file:	.RES	1

.CODE


.EXPORT	megagw_jump_table
megagw_jump_table:
	.WORD	gw_activate		; func  0
	.WORD	gw_shutdown		; func  1
	.WORD	gw_get_info_str		; func  2

	.WORD	gw_print_asciiz		; func  3
	.WORD	gw_print_char		; func  4
	.WORD	gw_print_crlf		; func  5
	.WORD	gw_print_hex_digit	; func  6
	.WORD	gw_print_hex_byte	; func  7
	.WORD	gw_print_hex_word	; func  8
	.WORD	gw_get_key		; func  9
	.WORD	gw_print_asciiz_inline  ; func 10

	.WORD	gw_hdos_dir_init	; func 11
	.WORD	gw_hdos_dir_read	; func 12
	.WORD	gw_hdos_cd_root		; func 13
	.WORD	gw_hdos_cd		; func 14


;	.WORD	gw_hdos_open_file
;	.WORD	gw_hdos_open_dir
;	.WORD	gw_hdos_read_dir
;	.WORD	gw_hdos_close_dir
;	.WORD	gw_hdos_read_file
;	.WORD	gw_hdos_cd_root
;	.WORD	gw_hdos_cd
;	.WORD	gw_attach
;	.WORD	gw_mount
.EXPORT	megagw_calls
megagw_calls = (* - megagw_jump_table) / 2




.PROC	gw_activate
	INC	cpu_a			; modify 8080 A register to signal the presence of MEGA/80
	LDA	cpu_b
	CMP	#'M'
	BNE	bad
	LDA	cpu_c
	CMP	#'e'
	BNE	bad
	LDA	cpu_d
	CMP	#'G'
	BNE	bad
	LDA	cpu_e
	CMP	#'a'
	BNE	bad
	.IMPORT	is_megagw_active
	STA	is_megagw_active	; Accu is non-zero, so it's OK to use here to activate
	RTS
bad:	WRISTR	{13,10,"*** WARN: bad MEGAGW act.seq.",13,10}
	RTS
.ENDPROC


.PROC	gw_shutdown
	; Make sure we closed all HDOS files
	JSR	hdos_closeall
	; Do the reset ...
	SEI
	LDA	#0
	TAX
	TAY
	TAZ
	MAP
	EOM
	DEA
	STA	1
	STA	$D02F		; VIC KEY register, let's mess it up
	JMP	($FFFC)
.ENDPROC


.PROC	gw_get_info_str
	.IMPORT	build_info_str
	LDX	#0
	LDZ	#0
:	LDA	build_info_str,X
	STA32Z	cpu_hl
	BEQ	:+
	INX
	INZ
	BNE	:-
:	RTS
.ENDPROC


.PROC	gw_print_asciiz
	LDZ	#0
:	LDA32Z	cpu_hl
	BEQ	:+
	JSR	write_char
	INZ
	BNE	:-
:	RTS
.ENDPROC


.PROC	gw_print_asciiz_inline
	LDZ	#0
:	LDA32Z	cpu_pc
	BEQ	:+
	JSR	write_char
	INW	cpu_pc
	BNE	:-
:	INW	cpu_pc
	RTS
.ENDPROC


.PROC	gw_print_char
	LDA	cpu_a
	JMP	write_char
.ENDPROC


gw_print_crlf = write_crlf


.PROC	gw_print_hex_digit
	LDA	cpu_a
	JMP	write_hex_nib
.ENDPROC


.PROC	gw_print_hex_byte
	LDA	cpu_a
	JMP	write_hex_byte
.ENDPROC


.PROC	gw_print_hex_word
	LDA	cpu_h
	JSR	write_hex_byte
	LDA	cpu_l
	JMP	write_hex_byte
.ENDPROC


.PROC	gw_get_key
	JSR	conin_get_with_wait
	STA	cpu_a
	RTS
.ENDPROC


.PROC	hdos_setname_from_hl
	LDX	#0
	LDZ	#0
:	LDA32Z	cpu_hl
	STA	HDOS_BUFFER,X
	BEQ	:+
	INX
	INZ
	BNE	:-
:	LDY	#>HDOS_BUFFER
	LDX	#0
	LDA	#$2E
	STA	$D640
	CLV
	RTS
.ENDPROC


.EXPORT	hdos_closeall
.PROC	hdos_closeall
	LDA	#$FF
	STA	fd_dir
	STA	fd_file
	LDA	#$22		; HDOS "close all" function
	STA	$D640
	CLV
	RTS
.ENDPROC


.PROC	gw_hdos_dir_init
	JSR	hdos_closeall
	LDA	#$12
	STA	$D640
	CLV
	STA	cpu_a
	BCC	:+
	STA	fd_dir
:	RTS
.ENDPROC


.PROC	gw_hdos_dir_read
	LDX	fd_dir
	BMI	not_open
	LDA	#$14
	LDY	#>HDOS_BUFFER
	STA	$D640
	CLV
	BCC	dir_error
	; Ok, copy things to HL
	LDX	#0
	LDZ	#0
:	LDA	HDOS_BUFFER,X
	STA32Z	cpu_hl
	INX
	INZ
	BNE	:-
	SEC
	RTS
dir_error:
	STA	cpu_a
	RTS
not_open:
	CLC
	RTS
.ENDPROC


.PROC	hdos_get_current_drive
	LDA	#$04
	STA	$D640
	CLV
	TAX
	RTS
.ENDPROC


.PROC	gw_hdos_cd_root
	JSR	hdos_get_current_drive	; X: disk ???????
	LDA	#$3C
	STA	$D640
	CLV
	STA	cpu_a
	RTS
.ENDPROC


.PROC	gw_hdos_cd
	JSR	hdos_setname_from_hl
	BCC	error
	LDA	#$34		; findfile
	STA	$D640
	CLV
	BCC	error
	LDA	#$0C
	STA	$D640
	CLV
error:	STA	cpu_a
	RTS
.ENDPROC
