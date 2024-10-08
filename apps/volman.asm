	ORG	0x100

	LD	HL, (5)
	LD	SP, HL
	; Get BIOS CONIN and CONOUT entry points
	LD	HL, (1)
	LD	BC, 3*3	; ptr at @1 points to BIOS WBOOT, 3 bytes per entries, move 3 forward: console output BIOS fnc
	ADD	HL, BC
	LD	(conout+1), HL
	DEC	HL
	DEC	HL
	DEC	HL
	LD	(conin+1), HL
	; Print host info
	LD	A, 2
	CALL	$FFFF
	LD	HL, $80
	CALL	print_asciiz
	; ********************************************************
	; Main menu loop
	; ********************************************************
main_menu:
	LD	HL, menu_text
	CALL	print_asciiz
.waitkey:
	CALL	conin
	CP	'1'
	JP	Z, task_mount_a
	CP	'2'
	JP	Z, task_mount_b
	CP	'3'
	JP	Z, task_format
	CP	'4'
	JP	Z, task_importer
	CP	'9'
	JP	Z, task_shutdown
	CP	'0'
	JP	NZ, .waitkey
	JP	0			; Exit to CP/M

task_shutdown:
	LD	HL, .msg
	CALL	print_asciiz
.ask:	CALL	conin
	CP	'y'
	JP	Z, .sure
	CP	'Y'
	JP	Z, .ask
	JP	main_menu
.sure:	XOR	A
	JP	$FFFF
	JP	0
.msg:	DB	"Press Y to confirm MEGA/80 CP/M shutdown (RAMDRIVE FS changes will be lost) ",0

task_mount_a:
task_mount_b:
task_format:
task_importer:
	LD	HL, .msg
	CALL	print_asciiz
	JP	main_menu
.msg:	DB	"TODO",13,10,0


print_asciiz:
	LD	A, (HL)
	OR	A
	RET	Z
	LD	C, A
	CALL	conout
	INC	HL
	JP	print_asciiz

conin:	JP	$0000	; the address will be modified
conout:	JP	$0000	; the address will be modified


menu_text:
	DB	13,10
	DB	"Volume manager for MEGA/80 (C)2024 Gabor Lenart LGB",13,10
	DB	13,10
	DB	"  1 ... Mount D81 as drive A:",13,10
	DB	"  2 ... Mount D81 as drive B:",13,10
	DB	"  3 ... Format D81 to MEGA/80 CP/M format",13,10
	DB	"  4 ... Start file importer shell",13,10
	DB	"  9 ... Shutdown MEGA/80",13,10
	DB	"  0 ... Exit to CP/M",13,10,0
