; vi: ft=z8a
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

	INCLUDE	"common.inc"

main:
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"MEGA/80 shell. Issue `help` for list of commands.", 13, 10, 0
main_loop:
	LD	A, '#'			; MEGA-SHELL prompt
	OUT	(GW_PRINT_CHAR), A
	LD	E, 78			; max size of input
	LD	HL, (trans)		; buffer ptr
	CALL	command_input
	; Check the command, and execute if valid
	LD	BC, cmd_table
.oloop:
	LD	HL, (trans)
	LD	D, 0			; difference counter
.iloop:
	LD	A, (BC)
	CP	(HL)
	JP	Z, .match_cmd_char
	INC	D
.match_cmd_char:
	INC	BC
	INC	HL
	OR	A
	JP	NZ, .iloop
	; End of string, check if D remained zero (found our command)
	LD	A, D
	OR	A
	JP	Z, .this_command
	; Not this command ...
	INC	BC			; skip the execution address
	INC	BC
	LD	A, (BC)			; check if it's end of command table
	OR	A
	JP	NZ, .oloop
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"*** Unknown command: ", 0
	LD	HL, (trans)
	OUT	(GW_PRINT_ASCIIZ), A
	OUT	(GW_PRINT_CRLF), A
	JP	main_loop
.this_command:
	LD	DE, main_loop
	PUSH	DE			; return address for tasks
	LD	A, (BC)
	LD	E, A
	INC	BC
	LD	A, (BC)
	LD	D, A
	PUSH	DE
	LD	A, (HL)			; A for tasks: -> next char in command line
	OR	A			; Z flag for tasks is set according 'A'
	RET				; use pushed DE as address!


; Command table:
; 0-byte terminated command name followed by a word (memory address of the command/task handler)
; End of table marker: 0
cmd_table:
	DB	"help", 0
	DW	task_help
	DB	"dir", 0
	DW	task_show_directory
	DB	"cd", 0
	DW	task_change_directory
	DB	"root", 0
	DW	task_change_root
	DB	"exit", 0
	DW	task_exit
	DB	"shutdown", 0
	DW	task_shutdown
	DB	"ver", 0
	DW	task_version
	DB	"attach", 0
	DW	task_attach
	DB	0


hdos_error:
	PUSH	AF
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	13, 10, "*** HDOS error: ", 0
	OUT	(GW_PRINT_ASCIIZ), A
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	": $", 0
	POP	AF
	OUT	(GW_PRINT_HEX_BYTE), A
	OUT	(GW_PRINT_CRLF), A
	RET


needs_parameter:
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	13, 10, "*** Command needs a parameter", 13, 10, 0
	RET


task_help:
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"Commands: ", 0
	LD	BC, cmd_table
.oloop:
	LD	A, (BC)
	OR	A
	JP	Z, .end
.iloop:
	LD	A, (BC)
	INC	BC
	OR	A
	JP	Z, .cmd_end
	OUT	(GW_PRINT_CHAR), A
	JP	.iloop
.cmd_end:
	INC	BC
	INC	BC
	LD	A, ' '
	OUT	(GW_PRINT_CHAR), A
	JP	.oloop
.end:
	OUT	(GW_PRINT_CRLF), A
	RET


command_input:
	LD	D, 0			; cmd line current size
	; Wait for keypress
.waitk:	OUT	(GW_GET_KEY), A
	LD	E, A
	CP	8
	JP	Z, .backspace
	CP	13
	JP	Z, .enter
	CP	32
	JP	Z, .space
	LD	A, D
	CP	78
	JP	Z, .waitk		; too long command line, do not accept input
	LD	A, E
	LD	(HL), A
	INC	D
	INC	HL
	OUT	(GW_PRINT_CHAR), A
	JP	.waitk
.backspace:
	LD	A, D
	OR	A
	JP	Z, .waitk		; empty, do not accept backspace
	DEC	HL
	DEC	D
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	8,32,8,0
	JP	.waitk
.space:
	LD	A, D
	OR	A
	JP	Z, .waitk		; do not accept space at the beginning of the command line
	CP	A, E
	JP	Z, .waitk		; too long command line
	DEC	HL
	LD	A, (HL)
	INC	HL
	OR	A
	JP	Z, .waitk		; previous char was space as well, ignore
	XOR	A			; store NULL character!
	LD	(HL), A
	INC	D
	INC	HL
	LD	A, 32			; print space
	OUT	(GW_PRINT_CHAR), A
	JP	.waitk
.enter:
	LD	A, D
	OR	A
	JP	Z, .waitk
	XOR	A
	LD	(HL), A			; close the string
	INC	HL
	LD	(HL), A
	OUT	(GW_PRINT_CRLF), A
	RET


task_show_directory:
	OUT	(GW_INIT_DIR), A
	JP	NC, .dir_open_error
.show_dir_loop:
	; Read directory
	LD	HL, (trans)
	OUT	(GW_READ_DIR), A
	JP	NC, .error_or_eod
	; Check if file is valid to print (not volname, etc)
	LD	BC, $56
	ADD	HL, BC
	LD	A, (HL)			; file attribute
	LD	D, A
	AND	8+4+2
	JP	NZ, .show_dir_loop	; this is a volume label, system file, or hidden: skip it
	; Print SPACE (normal file) or '>' (directory)
	LD	A, D
	AND	16
	LD	A, ' '
	JP	Z, .notdir
	LD	A, '>'
.notdir:
	OUT	(GW_PRINT_CHAR), A
	; Loop for printing the current filename
	LD	HL, (trans)
	LD	BC, 65
	ADD	HL, BC
	LD	D, 11
.loop:
	LD	A, (HL)
	OUT	(GW_PRINT_CHAR), A
	INC	HL
	LD	A, D
	CP	4
	JP	NZ, .nospace
	LD	A, ' '			; extra space between base file name and extension
	OUT	(GW_PRINT_CHAR), A
.nospace:
	DEC	D
	JP	NZ, .loop
	LD	A, ' '
	OUT	(GW_PRINT_CHAR), A
	LD	A, '|'
	OUT	(GW_PRINT_CHAR), A
	LD	A, ' '
	OUT	(GW_PRINT_CHAR), A
	JP	.show_dir_loop
.error_or_eod:
	CP	$85
	JP	NZ, .dir_read_error
	OUT	(GW_PRINT_CRLF), A
	RET
.dir_read_error:
	LD	HL, .msg_read_dir_err
	JP	hdos_error
.dir_open_error:
	LD	HL, .msg_open_dir_err
	JP	hdos_error
.msg_open_dir_err:
	DB	"open dir", 0
.msg_read_dir_err:
	DB	"read dir", 0


task_change_directory:
	JP	Z, needs_parameter
	OUT	(GW_CHDIR), A		; HL is already filled by the caller of task_change_directory
	RET	C
	LD	HL, .msg_change_dir_err
	JP	hdos_error
.msg_change_dir_err:
	DB	"change dir", 0


task_change_root:
	OUT	(GW_CHROOT), A
	RET	C
	LD	HL, .msg_change_rootdir_err
	JP	hdos_error
.msg_change_rootdir_err:
	DB	"change to root dir", 0


task_exit:
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"Good by(T)e!", 0
	JP	0


task_shutdown:
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"Press Y to confirm MEGA/80 CP/M shutdown (RAMDRIVE changes will be lost) ", 0
	OUT	(GW_GET_KEY), A
	; Check confirmation for shutdown
	CP	A, 'y'
	JP	Z, .doit
	CP	A, 'Y'
	JP	Z, .doit
	OUT	(GW_PRINT_CRLF), A
	RET	; not confirmed
.doit:	OUT	(GW_SHUTDOWN), A


task_version:
	LD	HL, (trans)
	OUT	(GW_GET_INFO_STR), A
	OUT	(GW_PRINT_ASCIIZ), A
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	13, 10, "BDOS at ", 0
	LD	HL, (6)
	OUT	(GW_PRINT_HEX_WORD), A
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	", BIOS at ", 0
	LD	HL, (1)
	OUT	(GW_PRINT_HEX_WORD), A
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	", CP/M system is ", 0
	LD	C, 12			; BDOS function: get version number
	CALL	5
	LD	A, H
	OUT	(GW_PRINT_HEX_BYTE), A
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	", CP/M version is ", 0
	LD	A, L
	OUT	(GW_PRINT_HEX_BYTE), A
	OUT	(GW_PRINT_CRLF), A
	RET


task_attach:
	JP	Z, needs_parameter
	OUT	(GW_ATTACH), A		; HL is already filled by the caller of task_change_directory
	RET	C			; op was OK!
	LD	HL, .msg_attach_err
	JP	hdos_error
.msg_attach_err:
	DB	"attach image", 0
