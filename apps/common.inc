; vi: ft=z8a.vim

	ORG	0x100

	LD	HL, (6)
	DEC	H		; leave 1K for the transfer buffer
	DEC	H
	DEC	H
	DEC	H
	LD	SP, HL
	LD	(trans), HL

	; MEGA-GW func #0: activation
	LD	BC, "Me"
	LD	DE, "Ga"
	XOR	A		; for test: if it's MEGA/80, the OUT op will modify 'A'
	OUT	(0), A
	OR	A
	JP	Z, no_mega80_error

	; Jump to the application
	JP	main

trans:
	DW	0

no_mega80_error:
	LD	C, 9
	LD	DE, .text
	CALL	5
	JP	0
.text:	DB	"This app needs MEGA/80$"



GW_SHUTDOWN		=  1
GW_GET_INFO_STR		=  2
GW_PRINT_ASCIIZ		=  3
GW_PRINT_CHAR		=  4
GW_PRINT_CRLF		=  5
GW_PRINT_HEX_DIGIT	=  6
GW_PRINT_HEX_BYTE	=  7
GW_PRINT_HEX_WORD	=  8
GW_GET_KEY		=  9
GW_PRINT_ASCIIZ_INLINE	= 10
GW_INIT_DIR		= 11
GW_READ_DIR		= 12
GW_CHROOT		= 13
GW_CHDIR		= 14
