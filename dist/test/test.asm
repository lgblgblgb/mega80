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



sd_cmp_temp:	.BYTE	0


.PROC	sd_wait
	LDA	irq_counter
	BMI	timeout
	LDA	$D680
	AND	#3
	BNE	sd_wait
	CLC
	RTS
timeout:
	SEC
	RTS
.ENDPROC


; Sector is relative to the mounting registers!
; Sector is always 512 bytes long (1600 of them on a D81)
; A=SD-card controller command to send
; X=D81 512 byte sector LBA, low byte
; Z= --""--, hi byte
; Y=current drive [MAKE SURE the drive is valid!!]
; SD buffer must be filled before (write-op), or read after (read-op)
.PROC	sd_op_lba
	; Save the SD-card command
	STA	sd_cmd_temp
	; Check if we're in the range (0..1599, ie 0-$63F)
	TZA
	CMP	#6
	BCC	doit
	BNE	error
	TXA
	CMP	#$40
	BCC	doit
timeout:
error:	SEC
	RTS
	; Calculate offset
doit:	TXA
	CLC
	ADC	drive_sd_img_base_b0,Y
	STA	$D681
	TZA
	ADC	drive_sd_img_base_b1,Y
	STA	$D682
	LDA	#0
	ADC	drive_sd_img_base_b2,Y
	STA	$D682
	LDA	#0
	ADC	drive_sd_img_base_b3,Y
	STA	$D683
	; Begint of timeout protected section
	LDA	#60		; give approx 1 sec of time for the operation to work out
	STA	irq_counter
	; Just to be on the safe side: wait for SD-controller to be ready
	JSR	sd_wait
	BCS	timeout
	; Issue the command
	LDA	sd_cmd_temp
	STA	$D680
	; Again, wait for SD-controller to be ready, now to finnish the command we've issued above
	JSR	sd_wait
	BCS	timeout
	; check error
	LDA	$D680
	AND	#$40+$20
	BNE	operr
	; OK :-)
	CLC
	RTS
.ENDPROC


; Uses 128 byte sector notion.
; One track is always 4 sectors
cpmimg_read_sector:


; Input: Y=current drive

.PROC	check_mega80_disk_format
	; Read disk, we need the first three "CBM sector" which needs two 512-bytes sectors to cover
	LDA	#SD_CMD_READ
	LDX
	LDZ
	JSR	sd_op_lba
	BCS	error
	JSR	sd
	LDA	#SD_CMD_READ
	LDX
	LDZ
	JSR	sd_op_lba
	BCS	error
	; copy to buffer


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
	; Check slice types
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


