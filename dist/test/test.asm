.WORD	$2001
.ORG	$2001
.SETCPU	"4510"
.SCOPE
	.WORD lastline, $FFFF
	; TODO: for me, BASIC 10 "BANK" keyword is quite confusing. According to the available documentation,
	; It's set the BANK number, with the extension that +128 means the "BASIC configuration" (I/O, etc)
	; However according to my tests, it's not true. Using BANK 128 here, still does not work. What I can
	; found only for a sane C65 loader is using BANK 0 before SYS, and doing all the memory MAP, etc then
	; in machine code for the desired mode. I will do that, in routine init_system, see later.
	.WORD $02FE					; "BANK" basic 10 token (double byte token, btw)
	.BYTE " 0 : "
	.BYTE $9E					; "SYS" basic token
	.BYTE " "
	.BYTE $30+.LOBYTE((stub_main .MOD 10000)/ 1000)
	.BYTE $30+.LOBYTE((stub_main .MOD  1000)/  100)
	.BYTE $30+.LOBYTE((stub_main .MOD   100)/   10)
	.BYTE $30+.LOBYTE( stub_main .MOD    10)
	.BYTE 0
lastline:
	.WORD 0
.ENDSCOPE

; Sector is relative to the mounting registers!
; Sector is always 512 bytes long (1600 of them on a D81)
sdimg_read_sector:
	; Check if we're in the range (0..1599, ie 0-$63F)
	LDA	sd_ofs+1
	CMP	#6
	BCC	ok
	BNE	error
	LDA	sd_ofs
	CM


	LDA	sd_img_base
	CLC
	ADC	sd_ofs
	STA	R
	LDA	sd_img_base+1
	ADC	sd_ofs+1
	STA	R+1
	LDA	sd_img_base+2
	ADC	#0
	STA	R+2
	LDA	sd_img_base+3
	ADC	#0
	STA	R+3
	; Initiate read command


; Uses 128 byte sector notion.
; One track is always 4 sectors
cpmimg_read_sector:



.PROC	check_mega80_disk_format
	; Check the format ID
	LDX	#5
:	LDA	diskid,X
	CMP	diskbuffer+$AD
	BNE	nope
	DEX
	BPL	:-
	; Check the copy of the slice entires (bit negated)
	LDX	#$3F
:	LDA	$0C0,X
	EOR	#$FF
	CMP	$3C0,X
	BNE	nope
	DEX
	BPL	:-
	; Check the slice names
	LDX	#14
:	LDA	nameid,X
	CMP	diskbuffer+$3C5,X
	BNE	nope
	CMP	diskbuffer+$3E5,X
	BNE	nope
	DEX
	BPL	:-
	LDA	diskbuffer+$3D4		; last char of slice0 filename
	INA
	CMP	diskbuffer+$3F4		; last char of slice1 filename
	BNE	nope
	CMP	#'1'
	BNE	nope
	; Check types
	LDA	#$85+$40
	CMP	diskbuffer+$3C2
	BNE	nope
	CMP	diskbuffer+$3E2
	BNE	nope
	; At this point, probably we're OK to trust that the disk is correct ...
	LDX	current_drive
	TODO: we want to read parameters from disk and apply to the system



nope:	; *** Not a MEGA/80 CP/M format disk ***
	SEC
	RTS
diskid: .BYTE "MEGA80"			;  6 bytes
nameid:	.BYTE "CP/M DISK POOL "		; 15 bytes
.ENDPROC





stub_main:
	LDA	$D68C
	ORA	$D68D
	ORA	$D68E
	ORA	$D68F
	BEQ	zero_is_invalid


	LDA	$D68C,X
	STA	sdsec





	RTS


