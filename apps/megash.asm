	INCLUDE	"common.inc"

main:
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"MEGA/80 shell. Invoke `help` command for some help.",13,10,0
main_loop:
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
	INC	BC		; skip the execution address
	INC	BC
	LD	A, (BC)		; check if it's end of command table
	OR	A
	JP	NZ, .oloop
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"Unknown command: ",0
	LD	HL, (trans)
	OUT	(GW_PRINT_ASCIIZ), A
	OUT	(GW_PRINT_CRLF), A
	JP	main_loop
.this_command:
	LD	DE, main_loop
	PUSH	DE	; return address for tasks
	LD	A, (BC)
	LD	E, A
	INC	BC
	LD	A, (BC)
	LD	D, A
	PUSH	DE
	LD	A, (HL)	; A for tasks: -> next char in command line
	RET		; use pushed DE as address!



cmd_table:
	DB	"help", 0
	DW	task_help
	DB	"dir",0
	DW	task_show_directory
	DB	"cd",0
	DW	task_change_directory
	DB	"root",0
	DW	task_change_root
	DB	0



task_help:
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
	LD	A, '#'			; MEGA-SHELL prompt
	OUT	(GW_PRINT_CHAR), A
	LD	HL, (trans)		; buffer ptr
	LD	D, 0			; cmd line size
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
	CP	A, 78
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
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	13,10,"Cannot read dir",13,10,0
	RET
.dir_open_error:
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	13,10,"Cannot open dir",13,10,0
	RET


task_change_directory:
	OR	A
	RET	Z
	OUT	(GW_CHDIR), A	; HL is already filled by the caller of task_change_directory
	JP	NC, .error
	RET
.error:
	PUSH	AF
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"Cannot change directory: ",0
	POP	AF
	OUT	(GW_PRINT_HEX_BYTE), A
	OUT	(GW_PRINT_CRLF), A
	RET


task_change_root:
	OUT	(GW_CHROOT), A
	RET	C
	PUSH	AF
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"Cannot change to root: ",0
	POP	AF
	OUT	(GW_PRINT_HEX_BYTE), A
	OUT	(GW_PRINT_CRLF), A
	RET
