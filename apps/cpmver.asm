; **** fragments of this is from my old project in 2017, thus is a huge mess ****
; Little CP/M utility to display CP/M version and
; some information, to test my emulator.
; [OLD-COMMENT Note: currently it's coded in an odd way, to]
; [OLD-COMMENT bridge problems present in my 8080 emulator.]

	ORG	0x100

	LD	HL, (6)
	LD	SP, HL
	PUSH	HL

	LD	A, 2	; function 2: get info string into DMA
	CALL	$FFFF
	LD	HL,0x80	; using the DMA
	CALL	print_string


	LD	HL,text1
	CALL	print_string

	POP	HL
	CALL	print_hex_word

	LD	HL, text2
	CALL	print_string
	LD	HL, (1)
	CALL	print_hex_word

	LD	HL,text3
	CALL	print_string

	LD	C,12		; BDOS function, get version number
	CALL	5
	PUSH	HL
	LD	A,H
	CALL	print_hex_byte

	LD	HL,text4
	CALL	print_string
	POP	HL
	LD	A,L
	CALL	print_hex_byte

	JP	0		; WBOOT, end of program


text1:	DB	13,10,"BDOS at ",0
text2:	DB	", BIOS at ",0
text3:	DB	", CP/M system is ",0
text4:	DB	", CP/M version is ",0


print_string:
	LD	A,(HL)
	OR	A
	RET	Z
	INC	HL
	CALL	print_char
	JP	print_string

print_hex_word:
	PUSH	HL
	LD	A,H
	CALL	print_hex_byte
	POP	HL
	LD	A,L
print_hex_byte:
	PUSH	AF
	RRCA
	RRCA
	RRCA
	RRCA
	CALL	print_hex_nib
	POP	AF
print_hex_nib:
	AND	15
	LD	B,0
	LD	C,A
	LD	HL,hextab
	ADD	HL,BC
	LD	A,(HL)
print_char:
	PUSH	AF
	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	E,A
	LD	C,2
	CALL	5
	POP	HL
	POP	DE
	POP	BC
	POP	AF
	RET

hextab:
	DB	'0123456789ABCDEF'
