; ----------------------------------------------------------------------------
;
; Software emulator of the 8080 CPU for the MEGA65, intended for CP/M or such.
; Please read comments throughout this source for more information.
;
; Copyright (C)2017 LGB (Gábor Lénárt) <lgblgblgb@gmail.com>
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

.BSS

cli_buffer:	.RES	80
hex_input:	.RES	2

.ZEROPAGE

memdump_addr:	.RES	4

.CODE



.PROC	skip_spaces_in_cli_buffer
	LDA	cli_buffer,X
	BEQ	return
	CMP	#32
	BNE	return
	INX
	JMP	skip_spaces_in_cli_buffer
return:
	RTS
.ENDPROC




; Input: X = position in cli_buffer to start
; Output: X = new position ...
;	  A = number of hex digits read
.PROC	get_hex_from_cli_buffer
	PHY
	LDA	#0
	TAY				; Y = number of hex digits could entered
	STA	hex_input
	STA	hex_input+1
loop:
	LDA	cli_buffer,X
	BEQ	end_of_hex		; end of buffer, end of hex input mode
	CMP	#32
	BEQ	end_of_hex		; space char, end of hex input mode
	SEC
	SBC	#'0'
	CMP	#10
	BCC	no_correction
	SBC	#7
	AND	#$F
no_correction:
	ASW	hex_input
	ASW	hex_input
	ASW	hex_input
	ASW	hex_input
	ORA	hex_input
	STA	hex_input
	INX
	INY
	JMP	loop
end_of_hex:
	TYA
	PLY
	ORA	#0
	RTS
.ENDPROC




.PROC	memdump
	LDX	#16
	; Begin: one line
line_loop:
	LDA	#' '
	JSR	write_char
	LDA	memdump_addr+3
	JSR	write_hex_byte
	LDA	memdump_addr+2
	JSR	write_hex_byte
	LDA	#':'
	JSR	write_char
	LDA	memdump_addr+1
	JSR	write_hex_byte
	LDA	memdump_addr
	JSR	write_hex_byte
	LDA	#' '
	JSR	write_char
	LDA	#' '
	JSR	write_char
	LDZ	#0
hex_loop:
	LDA32Z	memdump_addr
	JSR	write_hex_byte
	LDA	#' '
	JSR	write_char
	INZ
	CPZ	#16
	BNE	hex_loop
	LDA	#' '
	JSR	write_char
	LDA	#' '
	JSR	write_char
	LDZ	#0
char_loop:
	LDA32Z	memdump_addr
	BMI	:+
	CMP	#32
	BCS	:++
:	LDA	#'.'
:	JSR	write_char
	INZ
	CPZ	#16
	BNE	char_loop
	JSR	write_crlf
	; end: one line
	LDA	memdump_addr
	CLC
	ADC	#16
	STA	memdump_addr
	BCC	:+
	INC	memdump_addr+1
:	DEX
	BNE	line_loop
	RTS
.ENDPROC





.EXPORT	command_processor
.PROC	command_processor
	; TODO: move init to another place ...
	LDA	#.LOBYTE(I8080_BANK)
	STA	memdump_addr + 2
	LDA	#.HIBYTE(I8080_BANK)
	STA	memdump_addr + 3
	LDA	#0
	STA	memdump_addr
	STA	memdump_addr+1
shell_loop:
	LDA	#':'			; Console prompt
	JSR	write_char
	LDX	#0			; input buffer pointer
input_loop:
	JSR	conin_get_with_wait	; wait for next character ....
	CMP	#' '+1
	BCS	normal_char		; char code higher than space
	CPX	#0			; if not, check if buffer is empty
	BEQ	input_loop		; empty buffer cannot be entered, nor use delete key with, etc
	CMP	#' '
	BEQ	space_char		; special handle for space (see below at space_char label)
	CMP	#8
	BEQ	backspace_char		; backspace to delete
	CMP	#13
	BEQ	return_char		; return to enter buffer
	BNE	input_loop		; if non of above, let's loop back for waiting input
backspace_char:
	DEX
	WRISTR	{8,32,8}
	JMP	input_loop
space_char:
	CMP	cli_buffer-1,X		; we don't allow more spaces to be entered after each other
	BEQ	input_loop
normal_char:
	CPX	#78
	BEQ	input_loop
	JSR	write_char
	STA	cli_buffer,X
	INX
	BNE	input_loop
return_char:
	LDA	#32
	CMP	cli_buffer-1,X
	BNE	last_char_is_not_space
	DEX				; filter out unneeded trailing space
last_char_is_not_space:
	LDA	#0
	STA	cli_buffer,X		; store a null terminator in the buffer for easier processing later
	JSR	write_crlf
	JSR	search_command
	BMI	bad_command
	TAY
	LDA	cmdjumps_lo,Y
	STA	ja
	LDA	cmdjumps_hi,Y
	STA	ja+1
	ja = * + 1
	JMP	$8888
bad_command:
	WRISTR	{"?Bad command. Use 'help'.",13,10}
	JMP	shell_loop
.ENDPROC



; Output:
;	A = command number (negative if does not found), sign flag is set by this
;	X = cli_buffer position of possible param (C=1) or invalid when no param (C=0)
.PROC	search_command
	LDZ	#$FF				; command number counter (bits 0-6), comparsion failed signal (bit7=1)
	LDY	#$FF				; pointer in cmdnames table
cmd_search_loop:
	TZA
	INA					; next command for command counter
	AND	#$7F				; clear comparsion failed signal for the current command to be checked
	TAZ
	LDX	#$FF				; cli_buffer pointer
cmd_compare_loop:
	INX
	INY
	LDA	cmdnames,Y
	BEQ	cmd_not_found			; end of command names table, if we hit this point, we haven't found matching command, return!
	BMI	cmd_last_char_of		; command table contains bit7 set for the last char of each commands
	CMP	cli_buffer,X			; compare table with cli_buffer
	BEQ	cmd_compare_loop		; if match, continue
	TZA					; if doesn't match, set bit7 of Z, but still continue, for properly found the end of the table entry later
	ORA	#$80
	TAZ
	BNE	cmd_compare_loop		; =JMP here, always taken!
cmd_last_char_of:
	CPZ	#0				; here CPZ only used to check its bit7 without messing up accu (TZA wouldn't be a good idea, thus)
	BMI	cmd_search_loop
	AND	#$7F
	CMP	cli_buffer,X
	BNE	cmd_search_loop
	LDA	cli_buffer+1,X
	BEQ	cmd_found_with_no_param
	CMP	#32
	BNE	cmd_search_loop
	; So command found with a parameter
	INX					; move cli_buffer pointer to the parameter
	INX
	SEC
	TZA
	RTS
cmd_found_with_no_param:
	CLC
	TZA
	RTS
cmd_not_found:
	LDA	#$FF
	RTS
.ENDPROC



.PROC	dump_help
	LDY	#0
	LDX	#0
	LDA	#.HIBYTE(cmdhelps)
	STA	loop_help+2	; self-mod!!
main_loop:
	WRISTR	"  "
loop_cmd_name:
	LDA	cmdnames,Y
	LBEQ	write_crlf	; end
	INY
	TAZ
	AND	#$7F
	JSR	write_char
	TZA
	BPL	loop_cmd_name
	WRISTR	" : "
loop_help:
	LDA	cmdhelps,X
	INX
	BNE	:+
	INC	loop_help+2	; self-mod!!
:	TAZ
	AND	#$7F
	JSR	write_char
	TZA
	BPL	loop_help
	JSR	write_crlf
	JMP	main_loop
.ENDPROC


.PROC	error_no_param
	WRISTR	{"?Parameter missing.",13,10}
	JMP	command_processor::shell_loop
.ENDPROC
.PROC	error_bad_param
	WRISTR	{"?Bad parameter.",13,10}
	JMP	command_processor::shell_loop
.ENDPROC



.PROC	command_bank
	BCC	error_no_param
	JSR	get_hex_from_cli_buffer
	BEQ	error_bad_param
	WRISTR	"Dump bank is set to "
	LDA	hex_input+1
	AND	#$F
	STA	memdump_addr+3
	JSR	write_hex_byte
	LDA	hex_input
	STA	memdump_addr+2
	JSR	write_hex_byte
	JSR	write_crlf
	JMP	command_processor::shell_loop
.ENDPROC
.PROC	command_exit
	RTS
.ENDPROC
.PROC	command_help
	JSR	dump_help
	JMP	command_processor::shell_loop
.ENDPROC
.PROC	command_mem
	BCC	no_param
	JSR	get_hex_from_cli_buffer
	BEQ	error_bad_param
	LDA	hex_input
	STA	memdump_addr
	LDA	hex_input+1
	STA	memdump_addr+1
no_param:
	JSR	memdump
	JMP	command_processor::shell_loop
.ENDPROC
.PROC	command_regs
	JSR	reg_dump
	JMP	command_processor::shell_loop
.ENDPROC
.PROC	command_setpc
	LBCC	error_no_param
	JSR	get_hex_from_cli_buffer
	BEQ	error_bad_param
	WRISTR	"8080 PC is set to "
	LDA	hex_input+1
	STA	cpu_pch
	JSR	write_hex_byte
	LDA	hex_input
	STA	cpu_pcl
	JSR	write_hex_byte
	JSR	write_crlf
	JMP	command_processor::shell_loop
.ENDPROC


; Jump table for the given commands
; Order must be the same as with "cmdnames"
cmdjumps_lo:
	.LOBYTES	command_bank
	.LOBYTES	command_exit
	.LOBYTES	command_help
	.LOBYTES	command_mem
	.LOBYTES	command_regs
	.LOBYTES	command_setpc
cmdjumps_hi:
	.HIBYTES	command_bank
	.HIBYTES	command_exit
	.HIBYTES	command_help
	.HIBYTES	command_mem
	.HIBYTES	command_regs
	.HIBYTES	command_setpc
; Must be table of help messages for the given commands.
; Last char for each help msgs is bit7 set. No need for table termination.
; Order must be the same as with "cmdnames"
cmdhelps:
	.BYTE	"Set bank for mem cm", 'd'|128		; command "bank"
	.BYTE	"Exit shell, star", 't'|128		; command "exit"
	.BYTE	"You read tha",'t'|128			; command "help"
	.BYTE	"Dump memor", 'y'|128			; command "mem"
	.BYTE	"Show i8080 register",'s'|128		; command "regs"
	.BYTE	"Set i8080 P",'C'|128			; command "setpc"
; This table cannot be larger than 256 bytes!
; Last char for each cmd is bit7 set. Zero termination.
cmdnames:
	.BYTE	"ban",'k'|128
	.BYTE	"exi",'t'|128
	.BYTE	"hel",'p'|128
	.BYTE	"me",'m'|128
	.BYTE	"reg",'s'|128
	.BYTE	"setp",'c'|128
	.BYTE	0
