	INCLUDE	"common.inc"

main:
	OUT	(GW_INIT_DIR), A
	JP	NC, dir_open_error

.show_dir_loop:

	LD	HL, (trans)
	OUT	(GW_READ_DIR), A
	JP	NC, error_or_eod

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
	LD	A, ' '
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


error_or_eod:
	JP	0


dir_read_error:
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"Cannot read directory",0
	JP	0



dir_open_error:
	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	"Cannot open directory",0
	JP	0
