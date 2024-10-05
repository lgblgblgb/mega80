	ORG	$100

	; BDOS function to display a '$' terminated string
	LD	C,9
	LD	DE, msg
	CALL	5

	; BDOS function to get a character
	LD	C,1
	CALL	5
	CP	A,'y'
	JP	Z, shutdown
	CP	A,'Y'
	JP	Z, shutdown

	JP	0

shutdown:
	XOR	A		; Set A to zero for MEGA-GW function 0: shutdown, in this case no further parameter is needed
	JP	$FFFF


msg:	DB "Press Y to confirm MEGA/80 CP/M shutdown (FS changes - if any - will be lost) $"
