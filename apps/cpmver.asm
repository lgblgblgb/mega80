	INCLUDE	"common.inc"

main:
	LD	HL, (trans)
	OUT	(GW_GET_INFO_STR), A
	OUT	(GW_PRINT_ASCIIZ), A

	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	13,10,"BDOS at ",0

	LD	HL, (6)
	OUT	(GW_PRINT_HEX_WORD), A

	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	", BIOS at ",0

	LD	HL, (1)
	OUT	(GW_PRINT_HEX_WORD), A

	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	", CP/M system is ",0

	LD	C, 12			; BDOS function: get version number
	CALL	5

	LD	A, H
	OUT	(GW_PRINT_HEX_BYTE), A

	OUT	(GW_PRINT_ASCIIZ_INLINE), A
	DB	", CP/M version is ",0

	LD	A, L
	OUT	(GW_PRINT_HEX_BYTE), A

	JP	0			; Return to CP/M via WBOOT
